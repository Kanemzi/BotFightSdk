package core;

import utils.thread.ElasticThreadPool;
import sys.thread.*;
import core.action.Action;
import core.action.ActionCollector;
import core.action.ActionsResult;
import core.Player.PlayerInfo;
import core.Player.PlayerId;
import core.History.PlayerOutcome;

typedef ServerConfig = {
	var version : Int;
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

abstract PlayersActions<Ta : Action>(Array<PlayerActions<Ta>>) from Array<PlayerActions<Ta>> to Array<PlayerActions<Ta>> {

	@:op(a()) public function iter(f : (PlayerId, Ta, Int) -> Void) : Void {
		for (pa in this) 
			for (i in 0...pa.actions.length)
				f(pa.pid, pa.actions[i], i);
	}

	/*@:op(a()) public function filter(f : Ta -> Bool) : Array<PlayerActions<Ta>> {
		return this.filterMap(pa -> {
			var as = pa.actions.filter(f);
			return as.empty() ? null : { pid : pa.pid, actions : as };
		});
	}*/
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

	/**
		Called every update. Should mutate state depending on players actions.
		@todo : should returns logs (errors, warnings, debug) that will be sent back to players
			or out stream passed in parameters
		@todo : should provide rnd too ? (based on seed + turn)
	*/
	abstract function update(state : Ts, actions : PlayersActions<Ta>) : Void;
	abstract function getTurnActionProfile(pid : PlayerId) : TurnActionProfile<Ta>;
	abstract function getTiebreakerScore(pid : PlayerId) : Int;
	abstract function serializeHeaderForPlayer(pid : PlayerId,  initialState : Ts) : Array<String>;

	public function new(seed : Int, config : ServerConfig) {
		this.seed = seed;
		this.config = config;

		// @todo check bot count using config
		players = [];
		serializer = new hxbit.Serializer();
		serializer.remapIds = true;
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

		// @todo this behaviour might be defined in game parameters
		var alive = getAlivePlayers();
		if (alive.length == 1)
			victory(alive.map(p -> p.id));
	}

	final public function victory(pids : Array<PlayerId>) {
		if (turn == 0)
			throw 'Can\'t make any player win, the game hasn\'t started yet';

		for (p in getAlivePlayers())
			p.kill(pids.has(p.id) ? Victory : Defeated);
	}

	inline function getAlivePlayers() return players.filter(p -> p.isAlive());

	inline function cloneState(st : Ts) : Ts {
		// @todo will be required to support versioning and patching replay files on newer versions
		// serializer.beginSave();
		// serializer.addKnownRef(st);
		// var bytes = serializer.endSave();
		// serializer.beginLoad(bytes);
		// var cloned : Ts = cast serializer.getKnownRef(GameState);
		// serializer.endLoad();

		return cast serializer.unserialize(serializer.serialize(st), GameState);
	}

	final public function run() : History<Ts, Ta> {
		if (players.length < config.minPlayers || players.length > config.maxPlayers)
			throw "Trying to run a game with an invalid amount of players";

		turnModel = Type.createInstance(config.turnModel, []);
		
		final wto = Math.max(config.firstTurnTimeout, config.turnTimeout) * 2;
		turnWorkers = new ElasticThreadPool(players.length, wto / 1000.);

		history = new History(config.version, players, seed);
		history.addTurn(init(), []);

		for (p in players) {
			final header = serializeHeaderForPlayer(p.id, state);
			p.sendLines(header);
		}

		while (history.length < config.maxTurns) {
			var newState = cloneState(state);

			final alive = getAlivePlayers();
			final playing = turnModel.getPlayingThisTurn(getAlivePlayers(), newState, turn);
			final results = playTurns(playing);

			// @todo remove these logs, they should be stored in history for replay
			trace('--- Turn ${turn} ---');
			trace('Played : ${results.map(a -> '[${getPlayer(a.pid).name} : ${a.time}ms]').join(" ")}');
			trace('before : $state');

			inline function result(pid) return results.find(r -> r.pid == pid);

			for (r in results) {
				var logs = result(r.pid)?.logs;
				if (logs == null || logs.empty()) continue;
				trace('----- Player ${getPlayer(r.pid).name} logs for turn $turn -----');
				for (l in logs) trace(l);
			}

			// As of now, we sort players based on their response time.
			// Games can decide to ignore this order and process inputs in their own order
			var actions = getAlivePlayers()
				.map(p -> {pid : p.id, actions : result(p.id)?.actions ?? []});
			actions.sort((a, b) -> {
				final ae = a.actions.empty(), be = b.actions.empty();
				return if (ae != be) ae ? 1 : -1
					else if (ae) 0
					else result(a.pid).time > result(b.pid).time ? 1 : -1;
			});

			update(newState, actions);
			
			final defeats = alive.filter(p -> !p.isAlive());
			final victories = alive.filter(p -> p.status == Victory);

			for (d in defeats) history.outcome(d.id, Defeat(turn));
			for (v in victories) history.outcome(v.id, Victory(turn));

			history.addTurn(newState, results);
			if (!victories.empty())
				break;
			// @todo handle all players dead on same turn
		}

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

		dispose();

		return history.lock();
	}

	final function playTurns(players : Array<Player<Ta>>) : Array<ActionsResult<Ta>> {
		if (players.empty()) return [];

		inline function playTurn(player : Player<Ta>) : ActionsResult<Ta> {
			final tp = getTurnActionProfile(player.id);
			final timeout = turn <= 1 ? config.firstTurnTimeout : config.turnTimeout;
			final data = state.serializeForPlayer(player.id);
			player.sendLines(data);
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