package games.mines;

import core.GameState;
import core.Player.PlayerId;

enum ObjectKind { Mine; Scrap; Microship; }
typedef Resources = Map<ObjectKind, Int>;

@:publicFields
class Vec extends State {
	@:s var x : Int;
	@:s var y : Int;

	public function new(x, y) {
		super();
		this.x = x;
		this.y = y;
	}

	public inline function adjacent(o : Vec) {
		return hxd.Math.iabs(x - o.x) + hxd.Math.iabs(y - o.y) == 1;
	}
}

@:publicFields
class Robot extends State {
	@:s var pos : Vec;

	function new(x, y) {
		super();
		pos = new Vec(x, y);
	}
}

@:publicFields
class Object extends State {
	@:s var k : ObjectKind;
	@:s var pos : Vec;
	
	function new(k, x, y) {
		super();
		this.k = k;
		pos = new Vec(x, y);
	}
}

@:publicFields
class MinesPlayer extends State {
	@:s var pid : PlayerId;
	@:s var robots : Array<Robot>;
	@:s var resources : Resources;

	function new(pid) {
		super();
		this.pid = pid;
		robots = [];
		resources = [Scrap => 10, Microship => 2];
	}
}

// @todo try to have multiple owner situation to ensure it crashes

@:publicFields
class MinesState extends GameState {
	@:s var seed : Int;
	@:s var players : Array<MinesPlayer>;
	@:s var objects : Array<Object>;

	public inline static final WIDTH : Int = 16;
	public inline static final HEIGHT : Int = 16;

	public function new(pids : Array<PlayerId>, seed : Int) {
		super();
		this.seed = seed;

		players = pids.map(pid -> new MinesPlayer(pid));
		objects = [];

		// @todo generate intial robot
	}

	public inline function getPlayer(pid : PlayerId) return players.find(p -> p.pid == pid);
	public inline function getOwner(r : Robot) return players.find(p -> p.robots.contains(r));

	public inline function genRand(seed = 0) {
		return new hxd.Rand(this.seed + seed);
	}

	public function serializeForPlayer(pid : PlayerId) : Array<String> {
		return [];
	}
}