import haxe.Json;
import hxd.Rand;
import haxe.Exception;
import core.GameServer;
import core.GameState;
import core.History;
import core.Player.PlayerInfo;
import core.Player.PlayerId;
import core.action.Action;
import view.GameViewer;

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
	var rnd : hxd.Rand;

	@:generic
	public function new<Ts : GameState, Ta : Action>(cl : Class<GameServer<Ts, Ta>>, viewcl : Class<GameViewer<Ts>>, args : Array<String>) {
		final args = new RunnerArgs(args);
		seed = Std.parseInt(args.getParam("seed")) ?? Std.random(1 << 31 - 1);

		final paths = args.getParams("players"); 

		final debugGen = args.has("gen");
		var match = createMatch(args);
		for (p in paths)
			match.addPlayer(p);
		trace('Starting match on [${match.toString()}] format with ${match.players.length} players (seed=$seed)');

		while (!match.isComplete()) {
			final games = match.getNextGameBatch();
			for (candidates in games) {
				var gs = create(cl, candidates);
				var history = if (debugGen) {
					var h = new History(gs.config.version, gs.players);
					h.addTurn(gs.init(), []);
					for (p in candidates) h.outcome(p.id, Victory(0));
					h.lock();
				} else {
					gs.run();
				}
				match.onGameComplete(history);
			}
		}

		// Will play the path in priority or the current match if null
		final path = args.getParam("replay");
		replay(viewcl, path, match);

		//var hist = create(cl, players).run();
	}

	function replay<Ts : GameState, Ta : Action>(viewcl : Class<GameViewer<Ts>>, ?path : String, ?match : Match<Ts, Ta>) {
		if (path != null) {
			if (!sys.FileSystem.exists(path)) {
				trace('Match file $path does not exist');
				return;
			}
			try { 
				final bytes = sys.io.File.getBytes(path);
				final ser = new hxbit.Serializer();
				match = ser.unserialize(bytes, Match);
				// @todo check if match could be null here, or is it thrown
			} catch (e : Exception) {
				trace('Could not read match file $path : ${e.details()}');
				return;
			}
		}

		if (match == null) {
			trace("Nothing to replay");
			return;
		}

		var viewer = Type.createInstance(viewcl, [match]);
	}

	inline function create<Ts : GameState, Ta : Action>(cl : Class<GameServer<Ts, Ta>>, players : Array<PlayerInfo>) : GameServer<Ts, Ta> {
		var gs = Type.createInstance(cl, [genSeed()]);
		for (p in players) gs.addPlayer(p);
		return gs;
	}

	inline function genSeed() {
		return (rnd ??= new hxd.Rand(seed)).random(1 << 31 - 1);
	}

	static function createMatch<Ts : GameState, Ta : Action>(args : RunnerArgs) : Match<Ts, Ta> {
		if (args.has("gen")) {
			final n = Std.parseInt(args.getParam("gen")) ?? 1;
			return new Series(n);
		}
		
		final margs = args.getParams("match");
		if (margs.length > 0) {
			final format = margs.shift(); 
			switch (format) {
				case "series": return new Series(Std.parseInt(margs[0]));
				case "bo": return new BestOf(Std.parseInt(margs[0]));
				default:
			}
		} 
		return new Series(1);
	}
}