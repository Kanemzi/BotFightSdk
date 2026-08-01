package botfight.core;

import botfight.utils.thread.ElasticThreadPool;
import sys.thread.*;
import botfight.core.action.Action;
import botfight.core.action.ActionsResult;
import botfight.core.Player.PlayerId;
import botfight.core.Player.PlayerInfo;
import botfight.core.History.PlayerOutcome;
import botfight.core.Storage;
import botfight.core.GameSimulation.SimulationContext;
import botfight.live.LiveChannel;

typedef ServerConfig = {
	var version : Int;
	var ?minTeams : Int; // defaults to 2
	var ?maxTeams : Int; // defaults to 2
	var ?minTeamSize : Int; // defaults to 1
	var ?maxTeamSize : Int; // defaults to 1
	var maxTurns : Int;
	var firstTurnTimeout : Float;
	var turnTimeout : Float;
	var turnModel : Class<TurnModel>;
	var ?storageMode : Storage.StorageMode;
}

final class GameServer<Ts : GameState, Ta : Action> {
	var config(default, null) : ServerConfig;
	var seed(default, null) : Int;
	var players : Array<Player<Ta>>;

	var simuClass : Class<GameSimulation<Ts, Ta>>;
	var turnWorkers : ElasticThreadPool;

	function new(simuClass : Class<GameSimulation<Ts, Ta>>, config : ServerConfig, seed : Int) {
		this.config = config;
		this.seed = seed;
		this.simuClass = simuClass;

		// @todo check bot count using config
		players = [];
	}

	final public function addPlayer(info : PlayerInfo, io : PlayerIO<Ta>) {
		players.push(new Player<Ta>(info, io));
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

	final public function run(onBegin : History<Ts, Ta> -> Void, ?live : LiveChannel) : History<Ts, Ta> {
		final wto = Math.max(config.firstTurnTimeout, config.turnTimeout) * 2;
		turnWorkers = new ElasticThreadPool(players.length, wto / 1000.);
		
		final turnModel = Type.createInstance(config.turnModel, []);

		var history = new History(config.version, players, seed);
		var sim = Type.createInstance(simuClass, []);

		var ctx = new SimulationContext(players.map(p -> p.info), seed);

		final initState = sim.init(ctx);
		history.addTurn(initState, []);

		onBegin(history);
		live?.notify(GameBegin);

		inline function getTurn() return history.length;
		inline function getState() : Ts return history.turns.last().state;

		players.iter(p -> {
			p.sendLines(sim.serializeHeaderForPlayer(initState, p.id));
		});

		while (getTurn() < config.maxTurns) {
			final turn = getTurn();
			
			var newState = config.storageMode == Deterministic ? getState() : cloneState(getState());
			ctx.initTurn(turn, history.getAlivePlayers());

			final playing = turnModel.getPlayingThisTurn(ctx.getAlivePlayers(), newState, turn);
			final res = playTurns(turn, playing, newState, sim);
			res.iter(r -> if (r.status != Alive) ctx.defeat(r.pid));

			ctx.actions = ActionsResult.toPlayersActions(res);
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

			history.addTurn(newState, res);
			live?.notify(GameTurn);

			if (ctx.getAlivePlayers().empty() || !ctx.victories.empty())
				break;
		}

		final remain = history.getAlivePlayers();
		if (!remain.empty()) {
			final turn = getTurn();
			final scores : Map<PlayerId, Int> = [for (p in remain) p => sim.getTiebreakerScore(getState(), p)];
			final bestScore = scores[remain.max(p -> scores[p])];
			final winners = remain.copy().keep(p -> scores[p] == bestScore);
			for (p in remain) {
				final score = scores[p];
				final out = if (!winners.has(p)) Defeat(turn, score)
					else if (winners.length > 1) Draw(turn, score)
					else Victory(turn, score);
				history.outcome(p, out);
			}
		}

		dispose();

		history.lock();
		live?.notify(GameComplete);
		return history;
	}

	final function playTurns(turn : Int, pids : ReadOnlyArray<PlayerId>, state : Ts, sim : GameSimulation<Ts, Ta>) : Array<ActionsResult<Ta>> {
		if (pids.empty()) return [];
		var players = pids.map(getPlayer);

		inline function playTurn(player : Player<Ta>) : ActionsResult<Ta> {
			final tp = sim.getTurnActionProfile(state, player.id);
			final timeout = turn <= 1 ? config.firstTurnTimeout : config.turnTimeout;
			final data = sim.serializeForPlayer(state, player.id);
			return player.play(data, tp, timeout, sim);
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