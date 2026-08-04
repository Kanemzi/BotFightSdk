package server.state;

import cogpit.core.GameState;
import cogpit.core.GameState.WeakRef;
import cogpit.core.Player.PlayerId;
import server.TerrainGen;
import server.system.UnitBehaviourSystem.UnitBehaviourContext;

enum GroupOrder {
	Return;
	Rally(pos : Vec);
	Gather(pos : Vec, radius : Float);
	ConstructAt(pos : Vec, ?kind : Data.BuildingKind);
	Construct(target : WeakRef<Building>); // @todo place a building imediately on construct, but hidden. Destroy if still untouch when changing order
	Siege(target : WeakRef<Building>);
}

enum UnitPos {
	Garnison(bid : Int);
	Terrain(pos : Vec);
}

typedef Say = { msg : String, onUnit : Bool, expire : Int };

@:publicFields class Vec extends State {
	@:s var x : Float;
	@:s var y : Float;

	public function new(x = 0., y = 0.) {
		super();
		this.x = x;
		this.y = y;
	}

	public function clone() return new Vec(x, y);
}

package server.state;

enum BuildingStatus {
	Neutral;
	Constructing(p : WeakRef<WarPlayer>);
	Owned(p : WeakRef<WarPlayer>);
}

@:using(server.simulation.BuildingAction)
@:publicFields class Building extends State {
	@:s var bid(default, null) : Int;
	@:s var kind(default, null) : Data.BuildingKind;
	@:s var pos(default, null) : Vec;

	@:s var durability(default, null) : Int;
	@:s var status(default, null) : Int;
	@:s var order(default, null) : GroupOrder;
	@:s var sayInfo : Null<Say>;

	var leading(get, never) : WarPlayer;
	inline function get_leading() return switch (status) {
		case Constructing(p), Owned(p): p.get();
		default: null;
	}
	
	var owner(get, never) : WarPlayer;
	inline function get_owner() return switch (status) {
		case Owned(p): p.get();
		default: null;
	}
	
	function new(kind, pos) {
		// @todo bid attribution
		super();
		this.kind = kind;
		this.pos = pos;
		status = Neutral;
		order = Rally(pos.clone());
	}

	public function recruit(state : WarState, unit : Data.UnitKind) { // @todo returns a result ?
		if (owner == null) return;
		final data = Data.building.get(kind);
		final udata = Data.unit.get(unit);

		if (!data.recruits.exists(s -> s.unitId == unit)) return;
		if (state.getBuildingUnits(id).length >= data.maxUnits) return;
		//if (owner.get().hasResources()) // @todo ensure has resources

		var u = new Unit(unit, Out(pos.clone()), this);
		state.units.push(u);
	}

	/**
		Simulates one tick of u hitting in the building durability (combat unit or worker).
	*/
	function hit(u : Unit) {
		if (u.isOrphan) throw 'Orphan $kind [${u.uid}] should not be able to hit building.';
		final uOwner = u.building.get().owner;
		if (player != null && uOwner == player) throw '$kind [${u.uid}] should not be able to hit ally building.';
		changeDurability(-1, uOwner);
	}

	function changeDurability(v : Int, from : WarPlayer) {
		final cost = getCost();
		durability = hxd.Math.iclamp(v + durability, 0, cost);
		if (durability == 0 && v < 0) {
			if (owned) neutralize();
			else player = new WeakRef(from);
		} else if (durability == cost && v > 0) {
			if (owned) eject(); 
			else {
				if (player != from) throw 'Capturing clan [$from] was not the clan at advantage on the building [${player.get()}].';
				owned = true;
			}
		}
	}

	

	function neutralize() {
		player = null;
		owned = false;
		eject(true);
	}

	/**
		Ejects all units from the building. If not [all], garrisoned units parented to this building will stay
	*/
	function eject(all = false) {
		// @todo ejects all units from the building
	}

	function getCost() return Data.building.get(kind).cost.findMap(c -> c.itemId == Wood ? c.count : null);
}

@:publicFields class Unit extends State {
	@:s var uid : Int;
	@:s var kind : Data.UnitKind;
	@:s var pos : UnitPos;
	@:s var building : WeakRef<Building>;

	private var behaviour : UnitBehaviourContext;
	
	public var isOrphan(get, never) : Bool;
	inline function get_isOrphan() return building.get() == null;

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
	@:s var amount : Int;

	function new(kind, pos, amount) {
		super();
		this.kind = kind;
		this.pos = pos;
		this.amount = amount;
	}
}

@:publicFields class WarPlayer extends State {
	@:s var pid : PlayerId;
	@:s var inv : Inventory;

	function new(pid) {
		super();
		this.pid = pid;
		inv = new Inventory();
	}
}

// @todo replay events as EnumFlags<Event>

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