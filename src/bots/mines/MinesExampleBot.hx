package bots.mines;

/**
	Model classes
*/
typedef Vec = { x : Int, y : Int };
typedef Robot = { pos : Vec };
typedef Object = { pos : Vec };
typedef Inventory = { scrap : Int, microship : Int };
typedef GameState = {
	me : { inv : Inventory, robots : Array<Robot>},
	foes : { robots : Array<Robot> },
	mines : Array<Object>,
	scraps : Array<Object>,
	microships : Array<Object>,
};

class MinesExampleBot {

	static final stdin = Sys.stdin();
	static final stdout = Sys.stdout();

	static function parseState() : GameState {
		static final REG_INT = ~/^(\d+)$/;
		static final REG_HEADER = ~/^([A-Z]+) (\d+)$/;
		static final REG_POS = ~/^(\d+) (\d+)$/;

		function readInt() : Int {
			final line = stdin.readLine();
			if (!REG_INT.match(line)) throw 'Int expected, received "$line"';
			return Std.parseInt(REG_INT.matched(1));
		}

		function readSection<T : {}>(name : String, f : { pos : Vec } -> T) : Array<T> {
			final line = stdin.readLine();
			if (!REG_HEADER.match(line) || REG_HEADER.matched(1) != name) throw 'Header "$name" expected, received "$line"';

			var res = [];
			final c = Std.parseInt(REG_HEADER.matched(2));
			for (_ in 0...c) {
				final line = stdin.readLine();
				if (!REG_POS.match(line)) throw 'Vec expected, received "$line"';
				res.push(f({pos : {
					x : Std.parseInt(REG_POS.matched(1)), 
					y : Std.parseInt(REG_POS.matched(2)), 
				}}));
			}
			return res;
		}

		var state : GameState = {
			me : {
				inv : {
					scrap : readInt(),
					microship : readInt(),
				},
				robots : readSection("ME", o -> (o : Robot)),
			},
			foes : { robots : readSection("FOES",  o -> (o : Robot)) },
			mines : readSection("MINE", o -> (o : Object)),
			scraps : readSection("SCRAP", o -> (o  : Object)),
			microships : readSection("MICROSHIP", o -> (o : Object)),
		}
		return state;
	}

	public static inline function debug(msg : String) Sys.stderr().writeString('$msg\n');
	
	public static inline function getName() return "Michel~" + Std.random(10000);
	
	public static function main() {
		final args = Sys.args();
		if (args.indexOf("--config") != -1) {
			stdout.writeString('${getName()}\n');
			return;
		}

		var header = stdin.readLine();
		debug('HEADER : $header');

		while (true) loop();
	}

	static function loop() {
		final state = parseState();
		//debug('State : $state');
		
		final actionCount = state.me.robots.length;
		//debug('I got $actionCount actions to perform');
		//Sys.sleep(Std.random(100) / 1000.);
		for( _ in 0...actionCount)
			stdout.writeString('WAIT\n');
		stdout.flush();
	}
}