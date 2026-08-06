package server.state;

import cogpit.core.GameState.WeakRef;
import cogpit.core.GameState;
import cogpit.core.Player.PlayerId;
import haxe.ds.Option;
import server.TerrainGen.Sym;
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

	public function new(kind, pos, ?owner : Clan) {
		super();
		bid = id; // @todo used specific and shorter ids
		this.kind = kind;
		this.pos = pos;
		status = owner == null ? Neutral : Owned(owner);
		hp = owner == null ? 0 : getCost();
		inv = new Inventory();
		order = Rally(pos.clone());
	}

	@:pure function getCost() {
		return (data.cost : Iterable<Data.Building_cost>)
			.findMap(c -> c.itemId == Materials ? c.amount : null);
	}
}

class Unit extends State {
	@:s public var uid(default, null) : Int;
	@:s public var kind(default, null) : Data.UnitKind;
	@:s public var building(default, null) : WeakRef<Building>;

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

	public function new(kind : Data.UnitKind, building : Building, ?pos : Vec) {
		super();
		this.kind = kind;
		this.pos = pos == null ? Building(building.bid) : Terrain(pos);
		this.building = (building : WeakRef<Building>);
	}

	@:pure public function inside(?b : Building) : Bool {
		return pos.with(Building(bid) => b == null || bid == b.bid);
	}

	@:pure public function getStat(kind : Data.StatKind) : Float {
		return (data.baseStats : Iterable<Data.Unit_baseStats>)
			.findMap(s -> s.statId == kind ? s.val : null) ?? Data.stat.get(kind).def;
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

		final sym = TerrainGen.randSym(Const.Width / 2., Const.Height / 2., rnd);
		generateTerrain(sym, rnd);
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

	function generateTerrain(sym : Sym, rnd : hxd.Rand) {
		final MARGIN = 5.;
		final WORKER_SPREAD = 3.;

		function spreadAround(center : Vec) {
			final angle = rnd.rand() * hxd.Math.PI * 2;
			final r = rnd.rand() * WORKER_SPREAD;
			return new Vec(center.x + hxd.Math.cos(angle) * r, center.y + hxd.Math.sin(angle) * r);
		}

		final px = MARGIN + rnd.rand() * (Const.Width / 4 - MARGIN);
		final py = Const.Height / 2 + (rnd.rand() * MARGIN * 2) - MARGIN;
		final playerSpots = [];
		TerrainGen.iterSym(sym, px, py, (x, y) -> playerSpots.push(new Vec(x, y)), true);

		for (i in 0...clans.length) {
			final clan = clans[i];
			final house = new Building(House, playerSpots[i % playerSpots.length], clan);
			buildings.push(house);

			for (_ in 0...5)
				units.push(new Unit(Craftsman, house, spreadAround(house.pos)));
		}

		final cx = sym.c.x - Const.Width / 8;
		final cy = sym.c.y + (rnd.rand() * MARGIN * 2) - MARGIN;
		final neutralSpots = [];
		TerrainGen.iterSym(sym, cx, cy, (x, y) -> neutralSpots.push(new Vec(x, y)), true);
		for (pos in neutralSpots)
			buildings.push(new Building(House, pos));

		final RES_RATIO = switch (sym.k) { case Axe(true): 0.5; default: 1.; }
		final FOOD_COUNT = Std.int(4 * RES_RATIO);
		final MATERIALS_COUNT = Std.int(4 * RES_RATIO);

		function genResSpawns(kind : Data.ResourceKind, n : Int) {
			for (_ in 0...n) {
				final x = MARGIN + rnd.rand() * (Const.Width / 2 - MARGIN);
				final y = MARGIN + rnd.rand() * (Const.Height / 2 - MARGIN);
				final amount = 40 + rnd.random(40);
				TerrainGen.iterSym(sym, x, y, (x, y) -> resources.push(new Resource(kind, new Vec(x, y), amount)));
			}
		}

		genResSpawns(Food, FOOD_COUNT);
		genResSpawns(Materials, MATERIALS_COUNT);
	}
}