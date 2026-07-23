import haxe.Json;
import hxd.Rand;
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
			
			- game server started as a local process
				- Start server as headless or not ?

			- Threads to handle multiple matches at the same time (different or same matchups) ?
			- Possibility to request matches through an API ?


			Advanced :
			- Send haxe source code through a request, auto compile process
				- Allows wrapping user code in with other boilerplate / compatibility code
	*/

	var seed : Int;

	@:generic
	public function new<Ts : GameState, Ta : Action>(cl : Class<GameServer<Ts, Ta>>, viewcl : Class<GameViewer<Ts>>, args : Array<String>) {
		final args = new RunnerArgs(args);
		seed = Std.parseInt(args.getParam("seed")) ?? Std.random(1 << 31 - 1);

		final paths = args.getParams("players"); 

		final debugGen = args.has("gen");
		var match = createMatch(args, seed);
		for (p in paths)
			match.addPlayer(p);
		trace('Starting match on [${match.toString()}] format with ${match.players.length} players (seed=$seed)');

		while (!match.isComplete()) {
			final games = match.pollGames();
			for (g in games) {
				var gs = createGame(cl, g);
				var history = if (debugGen) {
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

		if (args.has("out"))
			saveReplay(args.getParam("out"), match);

		// Will play the path in priority or the current match if null
		// @todo allow replaying without requesting matches
		final path = args.getParam("replay");
		replay(viewcl, path, match);
	}

	function replay<Ts : GameState, Ta : Action>(viewcl : Class<GameViewer<Ts>>, ?path : String, ?match : Match<Ts, Ta>) {
		if (path != null) {
			match = try loadReplay(path) catch (e : Exception) {
				trace(e.details());
				null;
			}
		}

		if (match == null) {
			trace("Nothing to replay");
			return;
		}

		var viewer = Type.createInstance(viewcl, [match]);
	}

	inline function createGame<Ts : GameState, Ta : Action>(cl : Class<GameServer<Ts, Ta>>, info : GameInfo) : GameServer<Ts, Ta> {
		var gs = Type.createInstance(cl, [info.seed]);
		for (p in info.players) gs.addPlayer(p);
		return gs;
	}

	static function createMatch<Ts : GameState, Ta : Action>(args : RunnerArgs, seed : Int) : Match<Ts, Ta> {
		if (args.has("gen")) {
			final n = Std.parseInt(args.getParam("gen")) ?? 1;
			return new Series(n, seed);
		}
		
		final margs = args.getParams("match");
		if (margs.length > 0) {
			final format = margs.shift(); 
			switch (format) {
				case "series": return new Series(Std.parseInt(margs[0]), seed);
				//case "bo": return new BestOf(Std.parseInt(margs[0]));
				default:
			}
		} 
		return new Series(1, seed);
	}

	static inline final REPLAY_EXT = "replay"; 
	static function saveReplay<Ts : GameState, Ta : Action>(out : String, match : Match<Ts, Ta>) {
		final ser = new hxbit.Serializer();
		final bytes = ser.serialize(match);
		var path = new haxe.io.Path(out ?? ".");
		path.ext = REPLAY_EXT;
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