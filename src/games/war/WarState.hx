package games.war;

import core.GameState;
import core.Player.PlayerId;
import games.war.TerrainGen;

enum BuildingKind { House; Tower; }
enum UnitKind { Civilian; Military; }
enum ResourceKind { Wood; Food; }

@:publicFields
class Vec implements State {
	@:s var x : Float;
	@:s var y : Float;

	public function new(x, y) {
		this.x = x;
		this.y = y;
	}
}

@:publicFields
class Building implements State {
	@:s var id : Int;
    @:s var kind : BuildingKind;
	@:s var pos : Vec;

	function new(kind, pos, gs : WarState) {
		this.id = gs.buildingId++;
		this.kind = kind;
		this.pos = pos;
	}
}

@:publicFields
class Unit implements State {
	@:s var kind : UnitKind;
    @:s var pos : Vec;
	@:s var building : Null<Building>;

	function new(kind, pos, building) {
		this.kind = kind;
		this.pos = pos;
		this.building = building;
	}
}

@:publicFields
class Resource implements State {
	@:s var kind : ResourceKind;
	@:s var pos : Vec;
	@:s var radius : Float;
	@:s var amount : Int;

	function new(kind, pos, radius, amount) {
		this.kind = kind;
		this.pos = pos;
		this.radius = radius;
		this.amount = amount;
	}
}

@:publicFields
class WarPlayer implements State {
	@:s var pid : PlayerId;
    @:s var buildings : Array<Building>;
	@:s var units : Array<Unit>;

    function new(pid) {
		this.pid = pid;
	}

	function addBuilding() {

	}
}

class WarState extends GameState {
	@:s public var seed : Int;
	@:s public var players : Array<WarPlayer>;
	@:s public var resources : Array<Resource>;


	public inline static final WIDTH : Float = 100.; 
	public inline static final HEIGHT : Float = 60.; 

	@:allow(Building) var buildingId;

	public function new(players : Array<PlayerId>, seed : Int) {
		this.seed = seed;
		
		final rnd = new hxd.Rand(seed);
		final sym = TerrainGen.randSym(WIDTH / 2., HEIGHT / 2., genRand(rnd));
		
		resources = [];
		players = [for (pid in players) new WarPlayer(pid)];
		
		buildingId = 0;

		generateTerrain(sym, genRand(rnd));
	}

	public function serializeForPlayer(pid : PlayerId) : Array<String> {
		return [];
	}

	inline function genRand(rnd : hxd.Rand) {
		return new hxd.Rand(rnd.random(1 << 16));
	}

	function generateTerrain(sym : Sym, rnd : hxd.Rand) {
		final MARGIN = 10.;
		final RES_RATIO = switch (sym.k) {
			case Axe(true): 0.5;
			default: 1;
		}
		final WOOD_COUNT : Int = Std.int(10 * RES_RATIO);
		final FOOD_COUNT : Int = Std.int(10 * RES_RATIO);

		function genResSpawns(n: Int, f : (Float, Float) -> Void) {
			for (_ in 0...n) {
				var x = (rnd.rand() * (WIDTH / 2 - MARGIN)) + MARGIN;
				var y = (rnd.rand() * (HEIGHT / 2 - MARGIN * 2)) + MARGIN;
				TerrainGen.iterSym(sym, x, y, f);
			}
		}

		genResSpawns(WOOD_COUNT, (x, y) -> {
			final amount = 100 + rnd.random(100);
			final r = MARGIN * ((amount + 30) / 230);
			resources.push(new Resource(Wood, new Vec(x, y), r, amount));
		});

		genResSpawns(FOOD_COUNT, (x, y) -> {
			final amount = 100 + rnd.random(100);
			final r = MARGIN * ((amount + 30) / 230);
			resources.push(new Resource(Food, new Vec(x, y), r, amount));
		});

		var px = MARGIN + rnd.rand() * (WIDTH / 4 - MARGIN);
		var py = HEIGHT / 2 + (rnd.rand() * MARGIN * 2) - MARGIN;
		var ps = [];
		TerrainGen.iterSym(sym, px, py, (x, y) -> ps.push(new Vec(x, y)), true);
		for (p in players) {
			p.buildings.push(new Building(House, ps.shift()));
		}


		// @todo compute the total amount of resources based on unit and building costs and game difficulty
	}
}