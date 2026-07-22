package games.mines;

import games.mines.MinesState;

// @todo mines explode in 1 unit long cross patterns
// @todo destroyed robots spawn Scrap + chance of Microship

class Simulation {
	public inline static final MICROSHIP_SCORE_RATIO = 5;
	public inline static final MAX_TURNS = 200;

	public static final MINE_COST : Resources = [Scrap => 4];
	public static final ROBOT_COST : Resources = [Scrap => 5, Microship => 1];
	public static final ROBOT_DROPS : Map<ObjectKind, {max : Int, p : Float}> = [
		Scrap => {max : ROBOT_COST.get(Scrap), p : 0.5},
		Microship => {max : ROBOT_COST.get(Microship), p : 0.2},
	];
	public static final TURN_DROPRATES = [
		Scrap => 1.0 / 3.0,
		Microship => 1.0 / (MAX_TURNS / 20),
	];

	public static inline function shuffle<T>(a : Array<T>, ?rnd : hxd.Rand) {
		var len = a.length;
		for (i in 0...len) {
			var y = rnd?.random(len) ?? Std.random(len);
			var tmp = a[i];
			a[i] = a[y];
			a[y] = tmp;
		}
	}

	public static inline function inGrid(x : Int, y : Int) {
		if (x < 0 || y < 0) return false;
		if (x >= MinesState.WIDTH || y >= MinesState.HEIGHT) return false;
		return true;
	}

	public static inline function isEmpty(st : MinesState, x : Int, y : Int) {
		if (getObjectAt(st, x, y) != null) return false;
		if (getRobotAt(st, x, y) != null) return false;
		return true;
	}

	public static function cellMoveDist(x : Int, y : Int, tx : Int, ty : Int) {
		return hxd.Math.iabs(x - tx) + hxd.Math.iabs(y - ty);
	}

	public static function iterCellsAround(x : Int, y : Int, f : (Int, Int) -> Void, withSame = false, ?rnd : hxd.Rand) {
		var cells = null;
		var _f = f;
		if (rnd != null) {
			cells = [];
			f = (x, y) -> cells.push({x : x, y : y});
		}

		if (inGrid(x - 1, y)) f(x - 1, y);
		if (inGrid(x + 1, y)) f(x + 1, y);
		if (inGrid(x, y - 1)) f(x, y - 1);
		if (inGrid(x, y + 1)) f(x, y + 1);
		if (withSame && inGrid(x, y)) f(x, y);

		if (rnd != null) {
			shuffle(cells, rnd);
			for (c in cells) _f(c.x, c.y);
		}
	}

	public static function getEmptyCellAround(st : MinesState, x : Int, y : Int) {
		var cx = -1;
		var cy = -1;
		iterCellsAround(x, y, (ax, ay) -> {
			if (!isEmpty(st, ax, ay)) return;
			cx = ax;
			cy = ay;
		});
		return cx == -1 ? null : {x : cx, y : cy};
	}

	public static function getRandomCell(check : (Int, Int) -> Bool, rnd : hxd.Rand) {
		var tries = 1000;
		while (tries-- > 0) {
			var x = rnd.random(MinesState.WIDTH);
			var y = rnd.random(MinesState.HEIGHT);
			if (!check(x, y)) continue;
			return {x : x, y : y};
		}
		return null;
	}

	public static function getClosestCellAround(x : Int, y : Int, tx : Int, ty : Int) {
		var cx = -1;
		var cy = -1;
		var min = MinesState.WIDTH * MinesState.HEIGHT + 1;
		iterCellsAround(x, y, (ax, ay) -> {
			var d = cellMoveDist(ax, ay, tx, ty);
			if (d >= min) return;
			cx = ax; cy = ay;
			min = d;
		});
		return cx == -1 ? null : {x : cx, y : cy};
	}

	public static function forEachRobot(st : MinesState, f : Robot -> Void) {
		for (p in st.players)
			for (r in p.robots.copy())
				f(r);
	}

	public static function getRobotAt(st : MinesState, x : Int, y : Int) : Robot {
		var at = null;
		forEachRobot(st, r -> if (at == null) {
			if (r.pos.x != x || r.pos.y != y ) return;
			at = r;
		});
		return at;
	}

	public static function getObjectAt(st : MinesState, x : Int, y : Int) {
		return st.objects.find(o -> o.pos.x == x && o.pos.y == y);
	}

	public static function hasResources(p : MinesPlayer, res : Resources) {
		for (k => qty in res) {
			final pQty = p.resources.get(k);
			if (pQty == null || pQty < qty)
				return false; 
		}
		return true;
	}

	public static function consume(p : MinesPlayer, res : Resources) {
		if (!hasResources(p, res))
			throw 'Player ${p.pid}(with ${p.resources}) does not have enough resources to consume $res';
		
		for (k => qty in res) {
			final pQty = p.resources.get(k);
			p.resources.set(k, pQty - qty);
		}
	}

	// @todo use a seeded random
	public static function destroyRobotAt(st : MinesState, x : Int, y : Int, rnd : hxd.Rand) {
		var drops : Resources = [];
		inline function addDrops(k : ObjectKind) {
			final data = ROBOT_DROPS.get(k);
			var c = 0;
			for (_ in 0...data.max)
				if (rnd.rand() < data.p) c++;
			drops.set(k, c);
		}
		addDrops(Scrap);
		addDrops(Microship);

		iterCellsAround(x, y, (ax, ay) -> {
			final k = if (drops.get(Microship) ?? 0 > 0) Microship
				else if (drops.get(Scrap) ?? 0 > 0) Scrap
				else return;

			drops.set(k, drops.get(k) - 1);
			st.objects.push(new Object(k, ax, ay));
		}, true, rnd);
	}

	public static function turnDrops(st : MinesState, rnd : hxd.Rand) {
		function tryDrop(k : ObjectKind) {
			if (rnd.rand() >= TURN_DROPRATES.get(k)) return;
			
			var p = getRandomCell(isEmpty.bind(st), rnd);
			if (p == null) return;

			st.objects.push(new Object(k, p.x, p.y));
		}
		tryDrop(Scrap);
		tryDrop(Microship);
	}
}