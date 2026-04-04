package games.war;

import core.GameState;
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

	function new(id, kind, pos) {
		this.id = id;
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
    @:s var buildings : Array<Building>;
	@:s var units : Array<Unit>;

    function new() {}
}

class WarState extends GameState {
	@:s public var seed : Int;
	@:s public var players : Array<WarPlayer>;

	public inline static final WIDTH : Float = 100.; 
	public inline static final HEIGHT : Float = 60.; 

	public function new(playerCount : Int, seed : Int) {
		this.seed = seed;
		
		final rnd = new hxd.Rand(seed);
		final sym = TerrainGen.randSym(WIDTH / 2., HEIGHT / 2., genRand(rnd));
		generateTerrain(sym, genRand(rnd));
		
		
		players = [for (_ in 0...playerCount) new WarPlayer()];

	}

	inline function genRand(rnd : hxd.Rand) {
		return new hxd.Rand(rnd.random(1 << 16));
	}

	function generateTerrain(sym : Sym, rnd : hxd.Rand) {
		// @todo compute the total amount of resources based on unit and building costs and game difficulty
	}
}