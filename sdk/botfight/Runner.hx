package botfight;

import haxe.Exception;
import botfight.core.GameServer;
import botfight.core.GameServer.ServerConfig;
import botfight.core.GameSimulation;
import botfight.core.GameState;
import botfight.core.PlayerIO.ProcessPlayerIO;
import botfight.core.action.Action;
import botfight.core.Storage;
import botfight.viewer.GameViewer;
import botfight.Match;


final class RunnerArgs {
	var args(default, null) : Map<String, Array<String>>;
	public inline function new(as : Array<String>) {
		args = new Map();
		var last : String = null;
		for (arg in as) {
			if (arg.startsWith("--")) {
				last = arg.substring(2);
				args.set(last, []);
				continue;
			}

			if (last == null)
				continue;

			args.get(last)?.push(arg);
		}
	}

	public inline function has(arg : String) return args.exists(arg);
	public inline function getParams(arg : String) return args.get(arg);
	public inline function getParam(arg : String) {
		final p = getParams(arg);
		return p != null ? p[0] : null;
	}
}

@:access(botfight.core.GameServer)
@:access(botfight.Match)
final class Runner {
	/*
		Program launcher : Starts server and bot processes, checks compatibility among them
			- Allows starting a specific number of matches, registering stats, etc...

			- Threads to handle multiple matches at the same time (different or same matchups) ?
			- Possibility to request matches through an API ?


			Advanced :
			- Send haxe source code through a request, auto compile process
				- Allows wrapping user code in with other boilerplate / compatibility code
	*/

	public static inline function error(e : String) Sys.stderr().writeString('[Error] $e\n');

	@:generic
	public function new<Ts : GameState, Ta : Action>(
		simcl : Class<GameSimulation<Ts, Ta>>,
		viewcl : Class<GameViewer<Ts>>,
		arg : Array<String>,
		config : ServerConfig
	) {
		final args = new RunnerArgs(arg);
		final hasGen = args.has("gen");
		final hasMatch = args.has("match");
		final playerPaths = args.getParams("players");
		final playerCount = playerPaths.length;
		final teamSize = Std.parseInt(args.getParam("teamSize")) ?? 1;

		final shouldRunMatch = if (playerPaths == null || playerCount == 0) {
			// @todo debugGen should not require players (add dummy players)
			if (hasGen) error('Trying to test generation without any bot program.');
			else if (hasMatch) error('Trying to start a match without any bot program.');
			false;
		} else {
			// Ensure teams params are valid
			final teams = hxd.Math.floor(playerCount / teamSize);
			final remain = playerCount % teamSize;
	
			final minTeamSize = config.minTeamSize ?? 1;
			final maxTeamSize = config.maxTeamSize ?? 1;

			final minTeams = config.minTeams ?? 2;
			final maxTeams = config.maxTeams ?? 2;
			final term = teamSize == 1 ? 'players' : 'teams';

			if (teamSize < minTeamSize || teamSize > maxTeamSize) {
				var err = 'Team size should be between $minTeamSize and $maxTeamSize.';
				if (!args.has("teamSize"))
					err += 'Consider setting a team size for the match using --teamSize [n].';
				error(err);
				false;
			} else if (teams < minTeams) {
				final need = (minTeams - teams) * teamSize - remain;
				error('With $playerCount player(s), there would not be enough $term for the match.'
					+ 'Consider adding at least $need path(s) to the --players list.');
				false;
			} else if (teams > maxTeams) {
				final over = (teams - minTeams) * teamSize + remain;
				error('With $playerCount player(s), there would be too many $term for the match.'
					+ 'Consider adding removing $over path(s) from the --players list.');
				false;
			} else if (remain > 0) {
				var options = ['removing $remain path(s) from'];
				if (teams != maxTeams) options.unshift('adding ${teamSize - remain} path(s) to');
				error('$playerCount players does not allow forming even teams of $teamSize.'
					+ 'Consider ${options.join(' or ')} the --players list.');
				false;
			}
			true;
		}

		inline function runMatch() : Match<Ts, Ta> {
			var match = createMatch(args, teamSize);
			for (p in playerPaths)
				match.addPlayer(p);
			trace('Starting match on [${match.toString()}] format with ${match.players.length} players (seed=${match.seed})');

			while (!match.isComplete()) {
				final games = match.pollGames();
				for (g in games) {
					var gs = createGame(simcl, config, g);
					var history = if (hasGen) {
						throw 'Debug gen not supported yet';
						//var h = new History(gs.config.version, gs.players, gs.seed);
						//h.addTurn(gs.init(new hxd.Rand(gs.seed)), []);
						//for (p in g.players) h.outcome(p.id, Victory(0));
						//h.lock();
					} else {
						gs.run();
					}
					match.onGameComplete(history);
				}
			}
			return match;
		}

		var match = if (shouldRunMatch) {
			var m = runMatch();
			if (args.has("out"))
				Storage.saveMatch(args.getParam("out"), m, config.storageMode);
			m;
		} else null;

		final replayPath = args.getParam("replay");
		if (replayPath != null) {
			match = try Storage.loadMatch(replayPath) catch (e : Exception) {
				error(e.details());
				return;
			}
		}

		final headless = match == null || (args.has("headless") && replayPath == null);
		if (!headless)
			replay(simcl, viewcl, match);
	}

	static function createMatch<Ts : GameState, Ta : Action>(args : RunnerArgs, teamSize) : Match<Ts, Ta> {
		final seed = Std.parseInt(args.getParam("seed")) ?? Std.random(Const.INT_MAX);
		if (args.has("gen")) {
			final n = Std.parseInt(args.getParam("gen")) ?? 1;
			return new Series(n, seed, teamSize);
		}
		
		final margs = args.getParams("match");
		if (margs?.length > 0) {
			final format = margs.shift(); 
			switch (format) {
				case "series": return new Series(Std.parseInt(margs[0]), seed, teamSize);
				//case "bo": return new BestOf(Std.parseInt(margs[0]));
				default:
			}
		} 
		return new Series(1, seed);
	}

	inline function createGame<Ts : GameState, Ta : Action>(cl : Class<GameSimulation<Ts, Ta>>, config : ServerConfig, info : GameInfo) : GameServer<Ts, Ta> {
		var gs = new GameServer(cl, config, info.seed);
		for (p in info.players)
			gs.addPlayer(p, new ProcessPlayerIO<Ta>(p.path, []));
		return gs;
	}

	function replay<Ts : GameState, Ta : Action>(simcl : Class<GameSimulation<Ts, Ta>>, viewcl : Class<GameViewer<Ts>>, match : Match<Ts, Ta>) {
		if (match == null) {
			error("Nothing to replay");
			return;
		}
		
		for (g in match.games) g.recover(simcl, match);
		var viewer = Type.createInstance(viewcl, [match]);
	}
}