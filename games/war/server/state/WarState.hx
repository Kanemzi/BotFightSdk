package server.state;

import cogpit.core.GameState.WeakRef;
import cogpit.core.GameState;
import cogpit.core.Player.PlayerId;
import server.TerrainGen;
import server.system.ReplaySystem.BuildingReplayEvent;
import server.system.ReplaySystem.UnitReplayEvent;
import server.system.UnitBehaviourSystem.UnitBehaviourContext;

enum GroupOrder {
	Garrison;
	Rally(pos : Vec);
	Gather(pos : Vec, radius : Float);
	Construct(target : WeakRef<Building>);
	Siege(target : WeakRef<Building>);
}

enum UnitPos {
	Building(bid : Int);
	Terrain(pos : Vec);
}

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

enum BuildingStatus {
	Neutral;
	Constructing(p : WeakRef<Clan>);
	Owned(p : WeakRef<Clan>);
}

@:using(server.simulation.BuildingAction)
@:publicFields class Building extends State {
	@:s var bid(default, null) : Int;
	@:s var kind(default, null) : Data.BuildingKind;
	@:s var pos(default, null) : Vec;

	@:s var hp(default, null) : Int;
	@:s var status(default, null) : BuildingStatus;
	@:s var inv(default, null) : Inventory;

	@:allow(server.WarActions)
	@:s var order(default, null) : GroupOrder;

	@:allow(server.system.ReplaySystem)
	@:s public var replayEvents(default, null) : Array<BuildingReplayEvent>;

	public var data(get, null) : Data.Building;
	inline function get_data() return data ??= Data.building.get(kind);

	public var leading(get, never) : Null<Clan>;
	inline function get_leading() return status.with(Constructing(p) | Owned(p) => p.get());

	public var clan(get, never) : Null<Clan>;
	inline function get_clan() return status.with(Owned(p) => p);

	public function new(kind, pos) {
		super(); // @todo bid attribution
		this.kind = kind;
		this.pos = pos;
		status = Neutral;
		inv = new Inventory();
		order = Rally(pos.clone());
	}

	@:pure function getCost() return (cast data.cost).findMap(c -> c.itemId == Materials ? c.amount : null);
}

class Unit extends State {
	@:s public var uid(default, null) : Int;
	@:s public var kind(default, null) : Data.UnitKind;
	@:s public var building(default, null) : Null<WeakRef<Building>>;

	@:allow(server.TurnDeferred)
	@:s public var pos(default, null) : UnitPos;

	@:allow(server.system.ReplaySystem)
	@:s public var replayEvents(default, null) : Array<UnitReplayEvent>;

	@:allow(server.system.UnitBehaviourSystem)
	private var behaviour : UnitBehaviourContext;

	public var data(get, null) : Data.Unit;
	inline function get_data() return data ??= Data.unit.get(kind);

	public var clan(get, never) : Null<Clan>;
	@:pure inline function get_clan() return building?.get()?.clan;

	public var isOrphan(get, never) : Bool;
	@:pure inline function get_isOrphan() return clan == null;

	public function new(kind, building) {
		super();
		this.kind = kind;
		this.pos = Building(building.bid);
		this.building = cast building;
	}

	@:pure public function inside(?b : Building) : Bool {
		return pos.with(Building(bid) => b == null || bid == b.bid);
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

@:publicFields class Clan extends State {
	@:s var pid : PlayerId;
	@:s var inv : Inventory;

	function new(pid) {
		super();
		this.pid = pid;
		inv = new Inventory();
	}
}

// @todo replay events as EnumFlags<Event>
// @todo module for storing game statistics to display at the end (resources destroyed / consumed, units flee, etc...)
class WarState extends GameState {
	@:s public var clans : Array<Clan>;
	@:s public var units : Array<Unit>;
	@:s public var buildings : Array<Building>;
	@:s public var resources : Array<Resource>;

	public function new(pids : ReadOnlyArray<PlayerId>, rnd : hxd.Rand) {
		super();
		clans = pids.map(id -> new Clan(id));
		units = [];
		buildings = [];
		resources = [];
		
		/* final sym = TerrainGen.randSym(WIDTH / 2., HEIGHT / 2., rnd);
		generateTerrain(sym, rnd);*/
	}

	/**
		Finds a building based on its id. Will limit the search to a specific
		clan if [clan] is provided
	*/
	@:pure public function getBuildingById(id : Int, ?clan : PlayerId) {
		return buildings.find(b -> b.id == id && (clan == null || b.clan?.pid == clan)); 
	}

	@:pure public function getBuildingUnits(id : Int) {
		return units.filter(u -> u.building?.get()?.bid == id);
	}

	@:pure public function getClanBuildings(clan : PlayerId) {
		return buildings.filter(b -> b.clan?.pid == clan);
	}
	
	@:pure public function getClanUnits(clan : PlayerId) {
		return units.filter(u -> u.clan?.pid == clan);
	}
	
	@:pure public function getClan(clan : PlayerId) {
		return clans.find(p -> p.pid == clan);
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