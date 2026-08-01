package cogpit;

import haxe.Exception;
import cogpit.Match;
import cogpit.core.GameServer;
import cogpit.core.GameServer.ServerConfig;
import cogpit.core.GameSimulation;
import cogpit.core.GameState;
import cogpit.core.PlayerIO.ProcessPlayerIO;
import cogpit.core.action.Action;
import cogpit.core.Storage;
import cogpit.client.GameClient;
import cogpit.live.LiveChannel;

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

@:access(cogpit.core.GameServer)
@:access(cogpit.Match)
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

	public function new<Ts : GameState, Ta : Action>(
		simcl : Class<GameSimulation<Ts, Ta>>,
		clicl : Class<GameClient<Ts>>,
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

		final replayPath = args.getParam("replay");
		final headless = args.has("headless") && replayPath == null;
		final liveMode = args.has("live") && shouldRunMatch && !headless && replayPath == null;

		function buildMatch() {
			var match = createMatch(args, teamSize);
			for (p in playerPaths) match.addPlayer(p);
			return match;
		}

		function runMatch(match : Match<Ts, Ta>) : Void {
			trace('Starting match on [${match.toString()}] format with ${match.players.length} players (seed=${match.seed})');
			final gsFactory = createGame.bind(simcl, config);
			match.run(gsFactory);
			if (args.has("out"))
				Storage.saveMatch(args.getParam("out"), match, config.storageMode);
		}

		function replay(match : Match<Ts, Ta>, ?live : LiveChannel) {
			if (match == null) {
				error("Nothing to replay");
				return;
			}

			if (!liveMode) { // do not touch history, the game might be running
				for (g in match.games) g.history.recover(simcl, match); 
			}
			var client = Type.createInstance(clicl, [match, live]);
		}

		var match = shouldRunMatch ? buildMatch() : null;
		var live = null;
		if (liveMode) {
			live = new LiveChannel();
			match.watch(live);
			final t = sys.thread.Thread.create(runMatch.bind(match)); // @todo check where to close this
			t.name = 'GameServer';
		} else if (match != null) {
			runMatch(match);
		}

		if (replayPath != null) {
			match = try Storage.loadMatch(replayPath) catch (e : Exception) {
				error(e.details());
				return;
			}
		}

		if (match != null && !headless)
			replay(match, live);
	}

	function createMatch<Ts : GameState, Ta : Action>(args : RunnerArgs, teamSize : Int) : Match<Ts, Ta> {
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
				default:
			}
		} 
		return new Series(1, seed);
	}

	function createGame<Ts : GameState, Ta : Action>(cl : Class<GameSimulation<Ts, Ta>>, config : ServerConfig, game : GameSlot<Ts, Ta>) : GameServer<Ts, Ta> {
		var gs = new GameServer(cl, config, game.seed);
		for (p in game.players)
			gs.addPlayer(p, new ProcessPlayerIO<Ta>(p.path, []));
		return gs;
	}
}