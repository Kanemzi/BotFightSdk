package server.system;

import server.state.WarState.Unit;
import server.state.WarState.Vec;
import server.state.WarState;

class MovementSystem {
	public static function hasArrived(u : Unit, target : Vec) : Bool {
		return switch (u.pos) {
			case Building(_): false;
			case Terrain(pos): hxd.Math.distance(target.x - pos.x, target.y - pos.y) <= Const.ArrivalRadius;
		}
	}

	public static function resolveStep(u : Unit, target : Vec) : Null<Vec> {
		return switch (u.pos) {
			case Building(_): null;
			case Terrain(pos):
				final dx = target.x - pos.x;
				final dy = target.y - pos.y;
				final dist = hxd.Math.distance(dx, dy);
				if (dist <= Const.ArrivalRadius) null
				else {
					final step = hxd.Math.min(u.getStat(MoveSpeed), dist);
					new Vec(pos.x + dx / dist * step, pos.y + dy / dist * step);
				}
		}
	}

	// @todo only used for testing, needs to be improved later
	static var _slotRnd = new hxd.Rand(0);
	public static function computeTargetSlot(target : Vec, unit : Unit, radius : Float, out : Vec) : Vec {
		out ??= new Vec();
		_slotRnd.init(unit.id);
		var r = _slotRnd.rand() * radius;
		var a = _slotRnd.rand() * hxd.Math.PI * 2;
		out.x = target.x + hxd.Math.cos(a) * r;
		out.y = target.y + hxd.Math.sin(a) * r;
		return out;
	}
}
