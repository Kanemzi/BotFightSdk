package server.system;

import botfight.core.GameSimulation.PlayersActions;

import server.WarState;
import server.WarAction;

/**
	This system is in charge of handling players orders
*/
class OrderSystem {
	public static function applyActions(state : WarState, actions : PlayersActions<WarAction>) {
		actions.iter(a -> {
			final pid = a.pid;
			switch (a.actions) {
				case Say(bid, onUnit, msg):
					state.getBuildingById(bid, pid)?.say(msg, onUnit);

				case Move(bid, x, y, radius):
					state.getBuildingById(bid, pid)?.order = Guard(new Vec(x, y), radius);

				case Spawn(bid, _.toPascalCase() => unit):
					final data = Data.unit.resolve(unit, true);
					if (data == null) return; // Wrong id
					state.getBuildingById(bid, pid)?.spawn(state, unit);

				case Gather(bid, x, y, radius):
					state.getBuildingById(bid, pid)?.order = Gather(new Vec(x, y), radius);

				case Build(bid, x, y, _.toPascalCase() => building):
					final data = Data.building.resolve(building, true);
					if (data == null) return; // Wrong id
					state.getBuildingById(bid, pid)?.order = Construct(new Vec(x, y), building);

				case Attack(bid, tid):
					final taret = state.getBuildingById(tid);
					if (target == null) return; // Wrong id
					if (target.owner.get().id == pid) return; // Can't attack its own buildings 
					state.getBuildingById(bid, pid)?.order = Siege(new WeakRef(target));
			}
		});

		// Check Say actions expiry
		state.building.iter(b -> {
			if (b.say != null && b.say.expiry-- <= 0)
				b.say = null;
		});
	}
}