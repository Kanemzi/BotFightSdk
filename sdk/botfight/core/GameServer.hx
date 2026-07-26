package botfight.core;

import botfight.utils.thread.ElasticThreadPool;
import sys.thread.*;
import botfight.core.action.Action;
import botfight.core.action.ActionsResult;
import botfight.core.Player.PlayerInfo;
import botfight.core.Player.PlayerId;
import botfight.core.History.PlayerOutcome;
import botfight.core.Storage;
import botfight.core.GameSimulation.SimulationContext;

typedef ServerConfig = {
	var version : Int;
	var minPlayers : Int;
	var maxPlayers : Int;
	var maxTurns : Int;
	var firstTurnTimeout : Float;
	var turnTimeout : Float;
	var turnModel : Class<TurnModel>;
	var ?defaultStorageMode : Storage.StorageMode;
}

final class GameServer<Ts : GameState, Ta : Action> {
	var config(default, null) : ServerConfig;
	var seed(default, null) : Int;
	var players : Array<Player<Ta>>;
	var history : History<Ts, Ta>; // @todo save player and server logs per turn

	var state(get, never) : Ts;
	function get_state() return turn == 0 ? null : cast history.turns[turn - 1].state;
	
	var simuClass : Class<GameSimulation<Ts, Ta>>;
	var turnModel : TurnModel;
	var turn(get, never) : Int;
	function get_turn() return history.turns.length;

	var turnWorkers : ElasticThreadPool;

	function new(simuClass : Class<GameSimulation<Ts, Ta>>, config : ServerConfig, seed : Int) {
		this.config = config;
		this.seed = seed;
		this.simuClass = simuClass;

		// @todo check bot count using config
		players = [];
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

	public static inline function cloneState<Ts : GameState>(st : Ts) : Ts {
		// @todo will be required to support versioning and patching replay files on newer versions
		// serializer.beginSave();
		// serializer.addKnownRef(st);
		// var bytes = serializer.endSave();
		// serializer.beginLoad(bytes);
		// var cloned : Ts = cast serializer.getKnownRef(GameState);
		// serializer.endLoad();

		var ser = Storage.serializer;
		return cast ser.unserialize(ser.serialize(st), GameState);
	}

	final public function run() : History<Ts, Ta> {
		if (players.length < config.minPlayers || players.length > config.maxPlayers)
			throw "Trying to run a game with an invalid amount of players";

		final wto = Math.max(config.firstTurnTimeout, config.turnTimeout) * 2;
		turnWorkers = new ElasticThreadPool(players.length, wto / 1000.);
		
		turnModel = Type.createInstance(config.turnModel, []);

		history = new History(config.version, players, seed);

		var sim = Type.createInstance(simuClass, []);
		var initState = sim.init(history.getAlivePlayers(), new hxd.Rand(seed));

		history.addTurn(initState, []);

		for (p in players) {
			final header = sim.serializeHeaderForPlayer(state, p.id);
			p.sendLines(header);
		}
			
		while (history.length < config.maxTurns) {
			var newState = cloneState(state);
			var alive = history.getAlivePlayers().copy();

			final playing = turnModel.getPlayingThisTurn(alive, newState, turn);
			final results = playTurns(playing, sim);
			alive.keep(i -> results.find(r -> r.pid == i).status == Alive);

			final actions = ActionsResult.toPlayersActions(results);
			final turnSeed = seed + turn + 1;
			var ctx = new SimulationContext(actions, alive.copy(), turnSeed);
			sim.update(newState, ctx);

			// so Players might defeat themselves on timeout ?

			for (p in ctx.defeats) {
				getPlayer(p)?.kill(Defeated);
				history.outcome(p, Defeat(turn));
			}

			for (p in ctx.victories) {
				getPlayer(p)?.kill(Victory);
				history.outcome(p, Victory(turn));
			}

			// @todo the status should be updated in the results (defeat / victory) ?

			history.addTurn(newState, results);

			if (!ctx.victories.empty())
				break;
			// @todo handle all players dead on same turn
		}

		final remain = history.getAlivePlayers(); // victories not counted as alive
		if (!remain.empty()) {
			final scores = [for (p in remain) p => sim.getTiebreakerScore(state, p)];
			var victories = [];
			var max : Null<Int> = null;
			for (pid => score in scores) {
				if (max == null || score >= max) {
					if (score > max) victories.resize(0); 
					max = score;
					victories.push(pid);
				}
			}

			for (p in remain) {
				final score = scores[p];
				if (victories.has(p)) {
					final out = victories.length > 1 ? Draw(turn, score) : Victory(turn, score);
					history.outcome(p, out);
				} else {
					history.outcome(p, Defeat(turn, score));
				}
			}
		}

		dispose();

		return history.lock();
	}

	final function playTurns(pids : ReadOnlyArray<PlayerId>, sim : GameSimulation<Ts, Ta>) : Array<ActionsResult<Ta>> {
		if (pids.empty()) return [];
		var players = pids.map(getPlayer);

		inline function playTurn(player : Player<Ta>) : ActionsResult<Ta> {
			final tp = sim.getTurnActionProfile(state, player.id);
			final timeout = turn <= 1 ? config.firstTurnTimeout : config.turnTimeout;
			final data = sim.serializeForPlayer(state, player.id);
			player.sendLines(data);
			return player.collectActions(tp, timeout, sim);
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