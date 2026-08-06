typedef Building = { bid : Int, kind : String, clan : Int, x : Float, y : Float };
typedef Unit = { uid : Int, kind : String, bid : Int };

class WarExampleBot {

	public static inline function getName() return "Michel~" + Std.random(10000);

	static final stdin = Sys.stdin();
	static final stdout = Sys.stdout();

	static var PID : Int;
	static var WIDTH : Float;
	static var HEIGHT : Float;

	static final REG_INT = ~/^(-?\d+)$/;
	static function readInt() : Int {
		final line = stdin.readLine();
		if (!REG_INT.match(line)) throw 'Int expected, received "$line"';
		return Std.parseInt(REG_INT.matched(1));
	}

	static final REG_DIMS = ~/^([\d.]+) ([\d.]+)$/;
	static function readDims() {
		final line = stdin.readLine();
		if (!REG_DIMS.match(line)) throw 'Dimensions expected, received "$line"';
		WIDTH = Std.parseFloat(REG_DIMS.matched(1));
		HEIGHT = Std.parseFloat(REG_DIMS.matched(2));
	}

	static final REG_SECTION = ~/^([A-Z]+) (\d+)$/;
	static function readSection<T>(name : String, f : Array<String> -> T) : Array<T> {
		final header = stdin.readLine();
		if (!REG_SECTION.match(header) || REG_SECTION.matched(1) != name)
			throw 'Header "$name" expected, received "$header"';

		final count = Std.parseInt(REG_SECTION.matched(2));
		final res = [];
		for (_ in 0...count)
			res.push(f(stdin.readLine().split(" ")));
		return res;
	}

	static function parseBuilding(parts : Array<String>) : Building {
		return {
			bid : Std.parseInt(parts[0]),
			kind : parts[1],
			clan : Std.parseInt(parts[2]),
			x : Std.parseFloat(parts[3]),
			y : Std.parseFloat(parts[4]),
		};
	}

	static function parseUnit(parts : Array<String>) : Unit {
		return {
			uid : Std.parseInt(parts[0]),
			kind : parts[1],
			bid : Std.parseInt(parts[2]),
		};
	}

	public static function main() {
		final args = Sys.args();
		if (args.indexOf("--config") != -1) {
			stdout.writeString('${getName()}\n');
			return;
		}

		PID = readInt();
		readDims();

		while (true) loop();
	}

	static inline var DIRECTION_CHANGE_TURNS = 8;
	static inline var ROAM_TURNS = 120;
	static inline var GARRISON_TURNS = 30;
	static inline var CYCLE_TURNS = ROAM_TURNS + GARRISON_TURNS;
	static var turn = 0;

	static function loop() {
		turn++;

		final buildings = readSection("BUILDING", parseBuilding);
		readSection("UNIT", parseUnit);

		final house = buildings.filter(b -> b.kind == "H" && b.clan == PID)[0];
		if (house != null) {
			final t = (turn - 1) % CYCLE_TURNS;
			if (t == ROAM_TURNS) {
				stdout.writeString('GARRISON ${house.bid}\n');
			} else if (t < ROAM_TURNS && t % DIRECTION_CHANGE_TURNS == 0) {
				final x = Std.random(Std.int(WIDTH));
				final y = Std.random(Std.int(HEIGHT));
				stdout.writeString('RALLY ${house.bid} $x $y\n');
			}
		}

		stdout.writeString('END\n');
		stdout.flush();
	}
}
