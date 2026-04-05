import haxe.Json;
import hxd.Rand;
import core.GameServer;
import core.GameState;
import core.History;
import core.Player.PlayerInfo;
import core.Player.PlayerId;
import core.action.Action;

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
	public function new<Ts : GameState, Ta : Action>(cl : Class<GameServer<Ts, Ta>>, args : Array<String>) {
		final args = new RunnerArgs(args);
		seed = Std.parseInt(args.getParam("seed")) ?? Std.random(1 << 31 - 1);

		final paths = args.getParams("players"); 

		if (args.has("gen")) {
			var lobby = new Match<Ts, Ta>();
			var players = paths.map(lobby.addPlayer);
			var gs = create(cl, players);
			final state = gs.init();
			trace(state);
			return;
		}

		final match = getMatchFormat(args);
		for (p in paths) match.addPlayer(p);

		trace('Starting match on [${match.toString()}] format with ${match.players.length} players (seed=$seed)');

		// @todo with multithreaded games, wait for 1 game to complete to fetch next.
		// At this point, is no game is found, just lock the loop again until the next completed game
		while (!match.isComplete()) {
			final games = match.getNextGameBatch();
			for (candidates in games) {
				final h = create(cl, candidates).run();
				match.onGameComplete(h);
			}
		}

		//var hist = create(cl, players).run();
	}

	@:generic
	function create<Ts : GameState, Ta : Action>(cl : Class<GameServer<Ts, Ta>>, players : Array<PlayerInfo>) : GameServer<Ts, Ta> {
		var gs = Type.createInstance(cl, [genSeed()]);
		for (p in players) gs.addPlayer(p);
		return gs;
	}

	inline function genSeed() {
		return (rnd ??= new hxd.Rand(seed)).random(1 << 31 - 1);
	}

	static function getMatchFormat<Ts : GameState, Ta : Action>(args : RunnerArgs) : Match<Ts, Ta> {
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