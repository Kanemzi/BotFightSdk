package core;

import sys.thread.*;
import core.action.Action;
import core.action.ActionCollector;
import core.action.ActionsResult;
import core.Player.PlayerInfo;
import core.Player.PlayerId;
import core.History.PlayerOutcome;

typedef ServerConfig = {
	var version : String;
	var minPlayers : Int;
	var maxPlayers : Int;
	var maxTurns : Int;
	var firstTurnTimeout : Float;
	var turnTimeout : Float;
	var turnModel : Class<TurnModel>;
}

typedef PlayerActions<Ta : Action> = {
	var pid : PlayerId;
	var actions : Array<Ta>;
}

abstract class GameServer<Ts : GameState, Ta : Action> extends ActionParser<Ta> {
	var seed(default, null) : Int;
	var config(default, null) : ServerConfig;
	var players : Array<Player<Ta>>;
	var history : History<Ts, Ta>; // @todo save player and server logs per turn

	var state(get, never) : Ts;
	function get_state() return turn == 0 ? null : cast history.turns[turn - 1].state;
	
	var turnModel : TurnModel;
	var turn(get, never) : Int;
	function get_turn() return history.turns.length;

	var turnWorkers : ElasticThreadPool;

	var serializer : hxbit.Serializer;

	abstract function init() : Ts;
	abstract function update(state : Ts, actions : Array<PlayerActions<Ta>>) : Void;
	abstract function serializeStateForPlayer(pid : PlayerId) : Array<String>;
	abstract function getTurnActionProfile(pid : PlayerId) : TurnActionProfile<Ta>;
	abstract function getTiebreakerScore(pid : PlayerId) : Int;

	public function new(seed : Int, config : ServerConfig) {
		this.seed = seed;
		this.config = config;

		// @todo check bot count using config
		players = [];
		serializer = new hxbit.Serializer();
	}

	final public function addPlayer(info : PlayerInfo) {
		if (players.length >= config.maxPlayers) {
			throw 'Can\'t add player ${info.path}, the game already full';
		}
		players.push(new Player(info));
	}

	inline function getPlayer(pid : PlayerId) {
		return players.find(p -> p.id == pid);
	}

	final public function defeat(pid : PlayerId) {
		if (turn == 0)
			throw 'Can\'t defeat any player, the game hasn\'t started yet';

		var p = getPlayer(pid);
		if (p?.isAlive())
			p.kill(Defeated);
	}

	final public function victory(pids : Array<PlayerId>) {
		if (turn == 0)
			throw 'Can\'t make any player win, the game hasn\'t started yet';

		for (p in getAlivePlayers())
			p.kill(pids.has(p.id) ? Victory : Defeated);
	}

	inline function getAlivePlayers() return players.filter(p -> p.isAlive());

	final public function run() : History<Ts, Ta> {
		if (players.length < config.minPlayers || players.length > config.maxPlayers)
			throw "Trying to run a game with an invalid amount of players";

		turnModel = Type.createInstance(config.turnModel, []);
		
		final wto = Math.max(config.firstTurnTimeout, config.turnTimeout) * 2;
		turnWorkers = new ElasticThreadPool(players.length, wto / 1000.);

		history = new History(config.version, players);
		history.addTurn(init(), []);

		while (history.length < config.maxTurns) {
			var newState : Ts = cast serializer.unserialize(serializer.serialize(state), GameState);

			final alive = getAlivePlayers();
			final playing = turnModel.getPlayingThisTurn(getAlivePlayers(), newState, turn);
			final results = playTurns(playing);

			// @todo remove these logs, they should be stored in history for replay
			trace('--- Turn ${turn} ---');
			trace('Played : ${results.map(a -> '[${getPlayer(a.pid).name} : ${a.time}ms]').join(" ")}');
			trace('before : $state');


			inline function result(pid) return results.find(r -> r.pid == pid);

			// As of now, we sort players based on their response time.
			// Games can decide to ignore this order and process inputs in their own order
			var actions = getAlivePlayers()
				.map(p -> {pid : p.id, actions : result(p.id)?.actions ?? []});
			actions.sort((a, b) -> {
				final ae = a.actions.empty(), be = b.actions.empty();
				return if (ae != be) ae ? 1 : -1
					else if (ae) 0
					else result(a.pid).time - result(b.pid).time;
			});

			update(newState, actions);
			
			final defeats = alive.filter(p -> !p.isAlive());
			final victories = alive.filter(p -> p.status == Victory);

			for (d in defeats) history.outcome(d.id, Defeat(turn));
			for (v in victories) history.outcome(v.id, Victory(turn));

			history.addTurn(newState, results);
			if (!victories.empty())
				break;
		}

		dispose();

		final remaining = getAlivePlayers().filter(p -> p.status != Victory);
		if (!remaining.empty()) {
			final scores = [for (p in remaining) p.id => getTiebreakerScore(p.id)];
			var victories = [];
			var max : Null<Int> = null;
			for (pid => score in scores) {
				if (max == null || score >= max) {
					if (score > max) victories.resize(0); 
					max = score;
					victories.push(pid);
				}
			}

			for (p in remaining) {
				final score = scores[p.id];
				if (victories.has(p.id)) {
					final out = victories.length > 1 ? Draw(turn, score) : Victory(turn, score);
					history.outcome(p.id, out);
				} else {
					history.outcome(p.id, Defeat(turn, score));
				}
			}
		} 

		history.lock();
		return history;
	}

	final function playTurns(players : Array<Player<Ta>>) : Array<ActionsResult<Ta>> {
		if (players.empty()) return [];

		inline function playTurn(player : Player<Ta>) : ActionsResult<Ta> {
			final tp = getTurnActionProfile(player.id);
			final timeout = turn <= 1 ? config.firstTurnTimeout : config.turnTimeout;
			final state = serializeStateForPlayer(player.id);
			
			player.sendState(state);
			return player.collectActions(tp, timeout, this);
		}

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

	final function dispose() {
		for (p in players) p.kill(Terminated);
	}
}