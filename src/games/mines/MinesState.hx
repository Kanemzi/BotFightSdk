package games.mines;

import core.GameState;
import core.Player.PlayerId;

import games.mines.Simulation in Sim;

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
	// @todo mines should be owned by a player (for testing WeakRefs)
	// maybe then players could decide to Explode(x, y) their mines at any time
	
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

		var rnd = genRand();

		var p = players[0];
		var px = 1 + rnd.random(hxd.Math.round(WIDTH / 3) - 1);
		var py = 1 + rnd.random(hxd.Math.round(HEIGHT / 3) - 1);
		p.robots.push(new Robot(px, py));

		p = players[1];
		px = WIDTH - 1 - px;
		py = HEIGHT - 1 - py;
		p.robots.push(new Robot(px, py));

		// simulate turns of drops on the ground
		for (_ in 0...Sim.INIT_DROP_TURNS)
			Sim.turnDrops(this, rnd);

	}

	public inline function getPlayer(pid : PlayerId) return players.find(p -> p.pid == pid);
	public inline function getOwner(r : Robot) return players.find(p -> p.robots.contains(r));
	public inline function forEachRobot(?pid : PlayerId, f : Robot -> Void) {
		for (p in players) {
			if (pid != null && p.pid != pid) continue;
			for (r in p.robots.copy())
				f(r);
		}
	}

	public inline function genRand(seed = 0) {
		return new hxd.Rand(this.seed + seed);
	}

	public function serializeForPlayer(pid : PlayerId) : Array<String> {
		var l = [];
		
		var me = getPlayer(pid);
		l.push('${me.resources.get(Scrap)}');
		l.push('${me.resources.get(Microship)}');
		l.push('ME ${me.robots.length}');
		for (r in me.robots)
			l.push('${r.pos.x} ${r.pos.y}');

		var foes = [];
		forEachRobot(r -> if (getOwner(r).pid != pid) foes.push(r));
		l.push('FOES ${foes.length}');
		for (f in foes)
			l.push('${f.pos.x} ${f.pos.y}');

		var mines = objects.filter(o -> o.k == Mine);
		l.push('MINE ${mines.length}');
		for (o in mines)
			l.push('${o.pos.x} ${o.pos.y}');

		var scrap = objects.filter(o -> o.k == Scrap);
		l.push('SCRAP ${scrap.length}');
		for (o in scrap)
			l.push('${o.pos.x} ${o.pos.y}');

		var microship = objects.filter(o -> o.k == Microship);
		l.push('MICROSHIP ${microship.length}');
		for (o in microship)
			l.push('${o.pos.x} ${o.pos.y}');

		return l;
	}
}