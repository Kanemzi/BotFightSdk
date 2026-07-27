using Lambda;

class Rand {

	var seed : Int;
	var seed2 : Int;

	/**
		Create a random generator with a seed.
	**/
	public function new( seed : Int ) {
		init(seed);
	}

	/**
		Initialize the random generator with a seed.
	**/
	public function init(seed : Int) {
		this.seed = seed;
		this.seed2 = hash(seed);
		if( this.seed == 0 ) this.seed = 1;
		if( this.seed2 == 0 ) this.seed2 = 1;
	}

	// this is the Murmur3 hashing function which has both excellent distribution and good randomness
	public static function hash(n, seed = 5381) {
		return inlineHash(n, seed);
	}

	public static inline function inlineHash(n:Int, seed:Int) : Int {
		var n : haxe.Int32 = n;
		n *= 0xcc9e2d51;
		n = (n << 15) | (n >>> 17);
		n *= 0x1b873593;
		var h : haxe.Int32 = seed;
		h ^= n;
		h = (h << 13) | (h >>> 19);
		h = h*5 + 0xe6546b64;
		h ^= h >> 16;
		h *= 0x85ebca6b;
		h ^= h >> 13;
		h *= 0xc2b2ae35;
		h ^= h >> 16;
		return h;
	}

	/**
		Return a random integer between 0 and n (excluded).
	**/
	public inline function random( n ) {
		return uint() % n;
	}

	/**
		Shuffle values of an array.
	**/
	public inline function shuffle<T>( a : Array<T> ) {
		var len = a.length;
		for( i in 0...len ) {
			var x = random(len);
			var y = random(len);
			var tmp = a[x];
			a[x] = a[y];
			a[y] = tmp;
		}
	}

	/**
		Return a random float between 0.0 and 1.0 (excluded)
	**/
	public inline function rand() {
		// we can't use a divider > 16807 or else two consecutive seeds
		// might generate a similar float
		return (uint() % 10007) / 10007.0;
	}

	/**
		Return a random float between -scale and +scale (excluded)
	**/
	public inline function srand(scale=1.0) {
		return ((int() % 10007) / 10007.0) * scale;
	}

	// this is two Marsaglia Multiple-with-Carry (MWC) generators combined
	inline function int() : Int {
		seed = 36969 * (seed & 0xFFFF) + (seed >> 16);
		seed2 = 18000 * (seed2 & 0xFFFF) + (seed2 >> 16);
		return ((seed<<16) + seed2) #if js | 0 #end;
	}

	inline function uint() {
		return int() & 0x3FFFFFFF;
	}

	/**
		Create a randomized hxd.Rand (using a Std.random number as seed)
	**/
	public static function create() {
		return new Rand(Std.random(0x7FFFFFFF));
	}

}

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

	static final rnd = new Rand(0);

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
	
	public static inline function getName() return "Michel~" + rnd.random(10000);
	
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

	static var t = 0;
	static function loop() {
		t ++;
		if( t == 4) Sys.exit(0);
		final state = parseState();
		//debug('State : $state');
		
		final actionCount = state.me.robots.length;
		var spawned = false;
		var scrapLeft = state.inv.scrap;
		var microshipLeft = state.inv.microship;
		debug('[$PID][$t] I got $actionCount actions to play');

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
			var pos = { x : rnd.rand() < 0.5 ? -1 : 1, y : 0 }
			if (rnd.rand() < 0.5) {
				var tmp = pos.x;
				pos.x = pos.y;
				pos.y = tmp;
			}
			pos.x += bot.pos.x;
			pos.y += bot.pos.y;
			return pos;
		}

		function findMovePosition(bot : Robot) : Vec {
			if (rnd.rand() < 0.1) // cause why not
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
				if (!spawned && scrapLeft >= 5 && microshipLeft >= 1) {
					debug('[$PID][$t] Spawned');
					stdout.writeString('SPAWN\n');
					spawned = true;
					scrapLeft -= 5;
					microshipLeft -= 1;
					continue;
				}
			}

			// Chance to place mine near enemies
			if (scrapLeft > 4 * 5 && rnd.rand() < 0.2) {
				var c = closest(bot.pos, foes);
				if (c != null && dist(bot.pos, c) <= 3) {
					stdout.writeString('MINE ${c.x} ${c.y}\n');
					scrapLeft -= 4;
					continue;
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