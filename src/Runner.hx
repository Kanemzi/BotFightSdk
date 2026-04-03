import haxe.Json;
import core.GameServer;
import core.GameState;

final class RunnerArgs {
	var args : Map<String, Array<String>>;
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
}

final class Runner {
	/*
		Program launcher : Starts server and bot processes, checks compatibility among them
			- Allows starting a specific number of matches, registering stats, etc...
			
			- game server started as a local process
				- Start server as headless or not ?
			- bots are TCP clients or processes using stdin/out ?

			- Threads to handle multiple matches at the same time (different or same matchups) ?
			- Possibility to request matches through an API ?


			Advanced :
			- Send haxe source code through a request, auto compile process
				- Allows wrapping user code in with other boilerplate / compatibility code
	*/

	@:generic
	public function new<S : GameState, A : EnumValue>(cl : Class<GameServer<S, A>>, args : Array<String>) {
		var gs = Type.createInstance(cl, [args]);

		var args = new RunnerArgs(args);
        for (p in args.getParams("bots")) {
            gs.addPlayer(p);
        }

		trace(gs);
        gs.run();
	}
/*
	public static function main() {
		var args = Sys.args();
		trace(args);
		var serverPath = args.shift();

//		var a = new BotGameServer(args);
//		trace(a);

		var s = @:privateAccess GameServer.create(args);
		trace(s.getConfig());
		return;

		var config : ServerConfig = null;
		try {
			var p = new sys.io.Process('hl $serverPath --config');
			var line = p.stdout.readLine();
			config = cast haxe.Json.parse(line);
			p.close();
			trace('Current config : $config');
		} catch( e ) {
			trace('Could not read game server config : $e');
			return;
		}
	
		var botCount = args.length;
		if (botCount < config.minPlayers || botCount > config.maxPlayers) {
			trace("The amount of bots does not match the game server config");
			return;
		}				

		var serverArgs = args.join(" ");

		var p = new sys.io.Process('hl $serverPath $serverArgs --headless');
		var m = p.stdout.readLine();
		trace(m);
		p.close();

	}*/
}