package server;

import cogpit.core.GameState;
import cogpit.core.Player.PlayerId;

import server.Simulation in Sim;

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
	@:s var players : Array<MinesPlayer>;
	@:s var objects : Array<Object>;

	public inline static final WIDTH : Int = 16;
	public inline static final HEIGHT : Int = 16;

	public function new(pids : ReadOnlyArray<PlayerId>, rnd : hxd.Rand) {
		super();
		players = pids.map(pid -> new MinesPlayer(pid));
		objects = [];

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
}