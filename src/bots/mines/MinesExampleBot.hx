package bots.mines;

/**
	Model classes
*/
typedef Vec = { x : Int, y : Int };
typedef Robot = { pos : Vec };
typedef Object = { pos : Vec };
typedef Inventory = { scrap : Int, microship : Int };
typedef GameState = {
	inv : Inventory,
	me : { robots : Array<Robot>},
	foes : { robots : Array<Robot> },
	mines : Array<Object>,
	scraps : Array<Object>,
	microships : Array<Object>,
};

class MinesExampleBot {

	static final stdin = Sys.stdin();
	static final stdout = Sys.stdout();

	static var PID : Int;
	static var WIDTH : Int;
	static var HEIGHT : Int;

	static final REG_INT = ~/^(\d+)$/;
	static function readInt() : Int {
		final line = stdin.readLine();
		if (!REG_INT.match(line)) throw 'Int expected, received "$line"';
		return Std.parseInt(REG_INT.matched(1));
	}

	static final REG_VEC = ~/^(\d+) (\d+)$/;
	static function readVec() : Vec {
		final line = stdin.readLine();
		if (!REG_VEC.match(line)) throw 'Vec expected, received "$line"';
		return {
			x : Std.parseInt(REG_VEC.matched(1)), 
			y : Std.parseInt(REG_VEC.matched(2)), 
		};
	}

	static function parseState() : GameState {
		static final REG_HEADER = ~/^([A-Z]+) (\d+)$/;

		function readSection<T : {}>(name : String, f : { pos : Vec } -> T) : Array<T> {
			final line = stdin.readLine();
			if (!REG_HEADER.match(line) || REG_HEADER.matched(1) != name) throw 'Header "$name" expected, received "$line"';

			var res = [];
			final c = Std.parseInt(REG_HEADER.matched(2));
			for (_ in 0...c) {
				res.push(f({ pos : readVec() }));
			}
			return res;
		}

		var state : GameState = {
			inv : {
				scrap : readInt(),
				microship : readInt(),
			},
			me : { robots : readSection("ME", o -> (o : Robot)) },
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

		PID = readInt();
		var dim = readVec();
		WIDTH = dim.x;
		HEIGHT = dim.y;

		debug('Player $PID');

		while (true) loop();
	}

	static function loop() {
		final state = parseState();
		//debug('State : $state');
		
		final actionCount = state.me.robots.length;
		var spawned = false;

		var targets = state.scraps.concat(state.microships).map(o -> o.pos);
		var foes = state.foes.robots.map(f -> f.pos);

		function dist(a : Vec, b : Vec) {
			return Math.round(Math.abs(a.x - b.x) + Math.abs(a.y - b.y));
		}

		function closest(p : Vec, targets : Array<Vec>) : Vec {
			if (targets == null || targets.empty()) return null;
			var min = WIDTH * HEIGHT + 1.;
			var c = null;
			for (t in targets) {
				var d = dist(p, t);
				if (d < min) {
					min = d;
					c = t;
				}
			}
			return c;
		}

		function getRandomMove(bot : Robot) : Vec {
			var pos = { x : Std.random(100) < 50 ? -1 : 1, y : 0 }
			if (Std.random(100) < 100 ) {
				var tmp = pos.x;
				pos.x = pos.y;
				pos.y = tmp;
			}
			pos.x += bot.pos.x;
			pos.y += bot.pos.y;
			return pos;
		}

		function findMovePosition(bot : Robot) : Vec {
			if (Std.random(100) < 10) // cause why not
				return getRandomMove(bot);
			var c = closest(bot.pos, targets);
			if (c != null) {
				targets.remove(c);
				return c;
			}
			return null;
		}

		for (i in 0...actionCount) {
			var bot = state.me.robots[i];

			// player 0 is capped to 2 unit
			// other players are capped to 4 units
			var canSpawn = (PID == 0 && state.me.robots.length < 2)
				|| (PID > 0 && state.me.robots.length < 4);

			if (canSpawn) {
				if (!spawned && state.inv.scrap >= 5 && state.inv.microship >= 1) {
					stdout.writeString('SPAWN\n');
					spawned = true;
					continue;
				}
			}

			// Chance to place mine near enemies
			if (state.inv.scrap > 4 * 5 && Std.random(100) < 20) {
				var c = closest(bot.pos, foes);
				if (c != null && dist(bot.pos, c) <= 3) {
					stdout.writeString('MINE ${c.x} ${c.y}\n');
				}
			}

			var m = findMovePosition(bot);
			if (m != null) {
				stdout.writeString('MOVE ${m.x} ${m.y}\n');
				continue;
			}
			
			stdout.writeString('WAIT\n');
		}
		stdout.flush();
	}
}