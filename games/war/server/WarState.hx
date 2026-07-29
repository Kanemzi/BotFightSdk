package server;

import botfight.core.GameState;
import botfight.core.GameState.WeakRef;
import botfight.core.Player.PlayerId;
import server.TerrainGen;
import Data;

enum GroupOrder {
	Rally(pos : Vec);
	Return;
	Gather(pos : Vec, radius : Float);
	ConstructAt(pos : Vec, ?kind : Data.BuildingKind);
	Construct(target : WeakRef<Building>); // @todo place a building imediately on construct, but hidden. Destroy if still untouch when changing order
	Siege(target : WeakRef<Building>);
}

enum ConstructionStatus { Done; Pending(d : ConstructionInfo); }
@:publicFields class ConstructionInfo extends State {
	@:s var res : Resources;
	
	function new() { 
		super();
		res = new Map();
	}
}

enum UnitPos {
	Garnison;
	Out(pos : Vec);
}

typedef Resources = Map<Data.ResourceKind, Int>;
typedef Say = { msg : String, onUnit : Bool, expire : Int };

@:publicFields class Vec extends State {
	@:s var x : Float;
	@:s var y : Float;

	public function new(x, y) {
		super();
		this.x = x;
		this.y = y;
	}

	public function clone() {
		return new Vec(x, y);
	}
}

@:publicFields class Building extends State {
	@:s var bid : Int;
	@:s var kind : Data.BuildingKind;
	@:s var pos : Vec;
	@:s var owner : WeakRef<WarPlayer>;
	@:s var construction : ConstructionStatus;
	@:s var order : GroupOrder;
	@:s var sayInfo : Null<Say>;

	function new(kind, pos, owner) {
		// @todo bid attribution
		super();
		this.kind = kind;
		this.pos = pos;
		this.owner = new WeakRef(owner);
		construction = Done;
		order = Rally(pos.clone());
	}

	public inline function isFinished() return switch (construction) {
		case Done: true;
		default: false;
	}

	public function say(msg : String, onUnit : Bool) {
		sayInfo = { msg : msg, onUnit : onUnit, expire : Const.SayActionDuration };
	}

	public function recruit(state : WarState, unit : Data.UnitKind) { // @todo returns a result ?
		if (!isFinished()) return;
		final data = Data.building.get(kind);
		final udata = Data.unit.get(unit);

		if (!data.recruits.exists(s -> s.unitId == unit)) return;
		if (state.getBuildingUnits(id).length >= data.maxUnits) return;
		//if (owner.get().hasResources()) // @todo ensure has resources

		var u = new Unit(unit, Out(pos.clone()), this);
		state.units.push(u);
	}

	public static function makeConstructionSite(kind, pos, owner) : Building {
		var cs = new Building(kind, pos, owner);
		cs.construction = Pending(new ConstructionInfo());
		return cs;
	}
}

@:publicFields class Unit extends State {
	@:s var kind : Data.UnitKind;
	@:s var pos : UnitPos;
	@:s var building : WeakRef<Building>;

	// @todo units can be in garnison in their building (heal) ?

	function new(kind, pos, building) {
		super();
		this.kind = kind;
		this.pos = pos;
		this.building = new WeakRef(building);
	}
}

@:publicFields class Resource extends State {
	@:s var kind : Data.ResourceKind;
	@:s var pos : Vec;
	@:s var radius : Float;
	@:s var amount : Int;

	function new(kind, pos, radius, amount) {
		super();
		this.kind = kind;
		this.pos = pos;
		this.radius = radius;
		this.amount = amount;
	}
}

@:publicFields class WarPlayer extends State {
	@:s var pid : PlayerId;
	@:s var res : Resources;

	function new(pid) {
		super();
		this.pid = pid;
		res = new Map();
	}

	public function hasResources(r : Resources) {
		for (k => c in r) {
			final pc = res.get(k);
			if (pc == null || pc < c) return false; 
		}
		return true;
	}
}

class WarState extends GameState {
	@:s public var players : Array<WarPlayer>;
	@:s public var units : Array<Unit>;
	@:s public var buildings : Array<Building>;
	@:s public var resources : Array<Resource>;

	public function new(pids : ReadOnlyArray<PlayerId>, rnd : hxd.Rand) {
		super();
		/*
		final sym = TerrainGen.randSym(WIDTH / 2., HEIGHT / 2., rnd);
		*/
		players = pids.map(id -> new WarPlayer(id));
		units = [];
		buildings = [];
		resources = [];

//		generateTerrain(sym, rnd);
	}

	/**
		Finds a building based on its id. Will limit the search to a specific player
		if [owner] is provided
	*/
	public function getBuildingById(id : Int, ?owner : PlayerId) {
		return buildings.find(b -> b.id == id && (owner == null || b.owner.get().pid == owner)); 
	}

	public function getBuildingUnits(id : Int) {
		return units.filter(u -> u.building.get()?.bid == id);
	}

	public function getPlayerBuildings(id : PlayerId) {
		return buildings.filter(b -> b.owner.get().pid == id);
	}
	
	public function getPlayerUnits(id : PlayerId) {
		return getPlayerBuildings(id).flatMap(b -> getBuildingUnits(b.id));
	}
	
	public function getPlayer(id : PlayerId) {
		return players.find(p -> p.pid == id);
	}

/*
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
			p.buildings.push(new Building(House, ps.shift(), this));
		}
		
		// @todo compute the total amount of resources based on unit and building costs and game difficulty
	}
	*/
}