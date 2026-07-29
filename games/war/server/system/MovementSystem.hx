package server.system;

import server.WarState.Unit;

class MovementSystem {
	static var _tmpSlot = new Vec();
	public static function tick(state : WarState) {
		state.units.iter(u -> {
			if (u.isOrphan) {
				// @todo wander behavior
				return;
			}

			final b = u.building.get();
			switch (b.order) {
				case Rally(t):
					computeTargetSlot(t, u, 0, _tmpSlot);
					// @todo compute movement towards target slot 
				default:
			}
		});
	}

	// @todo only used for testing, needs to be improved later
	static var _slotRnd = new hxd.Rand(0);
	public static function computeTargetSlot(target : Vec, unit : Unit, radius : Float, out : Vec) : Vec {
		out ??= new Vec();
		_slotRnd.init(unit.id);
		var r = _slotRnd.rand() * radius;
		var a = _slotRand.rand() * hxd.Math.PI * 2;
		out.x = target.x + hxd.Math.cos(a) * r
		out.y = target.y + hxd.Math.sin(a) * r;
		return out;
	}
}