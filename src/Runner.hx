import haxe.Json;
import haxe.Exception;
import core.GameServer;
import core.GameState;
import core.History;
import core.Player.PlayerInfo;
import core.Player.PlayerId;
import core.action.Action;
import viewer.GameViewer;
import haxe.crypto.Base64;
import haxe.crypto.Md5;

import Match;

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

@:access(core.GameServer)
@:access(Match)
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

	var args : RunnerArgs;

	@:generic
	public function new<Ts : GameState, Ta : Action>(cl : Class<GameServer<Ts, Ta>>, viewcl : Class<GameViewer<Ts>>, arg : Array<String>) {
		this.args = new RunnerArgs(arg);
		final hasGen = args.has("gen");
		final hasMatch = args.has("match");
		final playerPaths = args.getParams("players");
		function shouldRunMatch() {
			if (playerPaths == null || playerPaths.length == 0) {
				// @todo debugGen should not require players (add dummy players)
				if (hasGen) error('Trying to test generation without any bot program');
				else if (hasMatch) error('Trying to start a match without any bot program');
				return false;
			}
			return true;
		}

		inline function runMatch() : Match<Ts, Ta> {
			var match = createMatch(args);
			for (p in playerPaths)
				match.addPlayer(p);
			trace('Starting match on [${match.toString()}] format with ${match.players.length} players (seed=${match.seed})');

			while (!match.isComplete()) {
				final games = match.pollGames();
				for (g in games) {
					var gs = createGame(cl, g);
					var history = if (hasGen) {
						var h = new History(gs.config.version, gs.players, gs.seed);
						h.addTurn(gs.init(), []);
						for (p in g.players) h.outcome(p.id, Victory(0));
						h.lock();
					} else {
						gs.run();
					}
					match.onGameComplete(history);
				}
			}
			return match;
		}

		var match = if (shouldRunMatch()) {
			var m = runMatch();
			if (args.has("out"))
				saveReplay(args.getParam("out"), m);
			m;
		} else null;

		final replayPath = args.getParam("replay");
		if (replayPath != null) {
			match = try loadReplay(replayPath) catch (e : Exception) {
				error(e.details());
				return;
			}
		}

		final headless = args.has("headless") && replayPath == null;
		if (!headless)
			replay(viewcl, match);		
	}

	static function createMatch<Ts : GameState, Ta : Action>(args : RunnerArgs) : Match<Ts, Ta> {
		final seed = Std.parseInt(args.getParam("seed")) ?? Std.random(1 << 31 - 1);
		if (args.has("gen")) {
			final n = Std.parseInt(args.getParam("gen")) ?? 1;
			return new Series(n, seed);
		}
		
		final margs = args.getParams("match");
		if (margs?.length > 0) {
			final format = margs.shift(); 
			switch (format) {
				case "series": return new Series(Std.parseInt(margs[0]), seed);
				//case "bo": return new BestOf(Std.parseInt(margs[0]));
				default:
			}
		} 
		return new Series(1, seed);
	}

	inline function createGame<Ts : GameState, Ta : Action>(cl : Class<GameServer<Ts, Ta>>, info : GameInfo) : GameServer<Ts, Ta> {
		var gs = Type.createInstance(cl, [info.seed]);
		for (p in info.players) gs.addPlayer(p);
		return gs;
	}

	function replay<Ts : GameState, Ta : Action>(viewcl : Class<GameViewer<Ts>>, match : Match<Ts, Ta>) {
		if (match == null) {
			error("Nothing to replay");
			return;
		}

		var viewer = Type.createInstance(viewcl, [match]);
	}

	static inline final REPLAY_EXT = "replay"; 
	static function saveReplay<Ts : GameState, Ta : Action>(out : String, match : Match<Ts, Ta>) {
		final ser = new hxbit.Serializer();
		final bytes = ser.serialize(match);
		var path = new haxe.io.Path(out ?? ".");
		path.ext = REPLAY_EXT;
		// @todo auto file name should be encoded based on bytes (but we should
		// exclude __uid from the hash so that it doesn't change with the same seed)
		// -> Allows checking if the game is deterministic
		// @todo checkDeterministic (bruteforce many games with different seeds to ensure the outcome is always the same)
		if (path.file.length == 0)
			path.file = Md5.encode('${match.seed}');

		if (path.dir != null && !sys.FileSystem.exists(path.dir) )
			sys.FileSystem.createDirectory(path.dir);

		var v = 0;
		var f = path.file;
		do {
			path.file = f + (v > 0 ? '_$v' : '');
			v++;
		} while (sys.FileSystem.exists(path.toString()));

		sys.io.File.saveBytes(path.toString(), bytes);
	}

	static function loadReplay<Ts : GameState, Ta : Action>(path : String) : Match<Ts, Ta> {
		if (!sys.FileSystem.exists(path))
			throw ('Replay file $path does not exist');
		
		try { 
			// @todo using "save/load" instead to keep versioning 
			final bytes = sys.io.File.getBytes(path);
			final ser = new hxbit.Serializer();
			return ser.unserialize(bytes, Match);
		} catch (e : Exception) {
			throw 'Could not read match file $path : ${e.details()}';
		}
	}
}