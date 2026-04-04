package core;

import sys.thread.*;
import core.action.Action;
import core.action.ActionCollector;
import core.action.ActionsResult;
import core.Player.PlayerInfo;
import core.Player.PlayerId;

typedef ServerConfig = {
	var version : String;
	var minPlayers : Int;
	var maxPlayers : Int;
	var maxTurns : Int;
	var firstTurnTimeout : Int;
	var turnTimeout : Int;
	var turnModel : Class<TurnModel>;
}

@:access(GameState)
abstract class GameServer<Ts : GameState, Ta : Action> extends ActionParser<Ta> {
	var seed(default, null) : Int;
	var config(default, null) : ServerConfig;
	var players : Array<Player<Ta>>;
	var history : History<Ts, Ta>; // @todo save player and server logs per turn

	var state(get, never) : Ts;
	function get_state() return cast history.turns[history.turns.length - 1].state;
	
	var turnModel : TurnModel;
	var turn(get, never) : Int;
	function get_turn() return history.turns.length;

	var turnWorkers : ElasticThreadPool;

	var serializer : hxbit.Serializer;

	abstract function init() : Ts; // Initializes the game state
	abstract function update(state : Ts) : Void; // Updates the state based on last player actions
	abstract function serializeStateForPlayer(player : Player<Ta>) : Array<String>;
	abstract function getTurnActionProfile(player : Player<Ta>) : TurnActionProfile<Ta>;

	public function new(seed : Int, config : ServerConfig) {
		this.seed = seed;
		this.config = config;

		// @todo check bot count using config
		players = [];
		serializer = new hxbit.Serializer();
	}

	public function addPlayer(info : PlayerInfo) {
		if (players.length >= config.maxPlayers) {
			throw 'Can\'t add player ${info.path}, the game already full';
		}
		players.push(new Player(info));
	}

	inline function getPlayer(id : PlayerId) {
		return players.find(p -> p.id == id);
	}

	inline function getAlivePlayers() return players.filter(p -> p.isAlive());

	final public function run() : History<Ts, Ta> {
		if (players.length < config.minPlayers || players.length > config.maxPlayers)
			throw "Trying to run a game with an invalid amount of players";

		turnModel = Type.createInstance(config.turnModel, []);
		
		final wto = Math.max(config.firstTurnTimeout, config.turnTimeout) * 2;
		turnWorkers = new ElasticThreadPool(players.length, wto / 1000.);

		history = new History(config.version, players);
		history.addTurn([], init());

		while (history.length < config.maxTurns + 1) {
			var newState : Ts = cast serializer.unserialize(serializer.serialize(state), GameState);

			final playing = turnModel.getPlayingThisTurn(getAlivePlayers(), newState, turn);
			final actions = playTurns(playing);

			// @todo remove these logs, they should be stored in history for replay
			trace('--- Turn ${history.turns.length} ---');
			trace('Played : ${actions.map(a -> '[${getPlayer(a.id).name} : ${a.time}ms]').join(" ")}');
			trace('before : $state');

			update(newState);
			trace('after : $state');
			
			history.addTurn(actions, newState);
		}

		dispose();
		/*var bytes = serializer.serialize(history);
		var hist = serializer.unserialize(bytes, History);
		trace(hist);
		*/
		return history;
	}

	function playTurns(players : Array<Player<Ta>>) : Array<ActionsResult<Ta>> {
		if (players.length == 0) return [];

		var results = [];
		var mutex = new Mutex();
		var lock = new Lock();
		for (p in players) {
			turnWorkers.run(() -> {
				final res = playTurn(p);
				mutex.acquire();
				results.push(res);
				if (results.length == players.length)
					lock.release();
				mutex.release();
			});
		}

		lock.wait();
		return results;
	}

	function playTurn(player : Player<Ta>) : ActionsResult<Ta> {
		final tp = getTurnActionProfile(player);
		final timeout = turn <= 1 ? config.firstTurnTimeout : config.turnTimeout;
		final state = serializeStateForPlayer(player);
		
		player.sendState(state);
		return player.collectActions(tp, timeout / 1000., this);
	}

	function dispose() {
		for (p in players) p.kill(Terminated);
	}
}