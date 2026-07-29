package server.system;

import botfight.core.GameState.WeakRef;
import botfight.core.GameSimulation.PlayerActions;
import botfight.core.GameSimulation.PlayersActions;
import botfight.core.Player.PlayerId;
import botfight.core.action.Action;
import botfight.core.action.ActionCollector;
import botfight.utils.Result;

import server.WarState;

// @todo macro should support multiple optional non strings params at the end of the line (default radius)

// @todo game turns are really short, since the simulation has a lot of micro and needs to be precise. But de players won't take decisions each turn (maybe every 10-20 turns).

/** Turn protocol
	- Bot sends multiple actions then and End action to finish its turn.
	- Max 1 action of each kind per building BUT
		- Some actions are decisions. Multiple different decisions can be sent per building
		- Some actions are targeted. Only 1 targeted decision per building
	ex: 
	Can't request (Gather + Construct) or (Siege + Rally) on same building in the same turn.
	But can request (Gather + Say). Limited to 1 say per building/turn
	Recruit has no target, therefore we can (Siege + Say + Recruit) on 1 building in the same turn.
**/

enum WarAction {
	/* All */
	Recruit(bid : Int, type : Word); // Spawn a new unit in [bid]. Cost will depend on the [unit] type
	Rally(bid : Int, x : Float, y : Float); // Units on [bid] will go and stay stationary around [x, y]
	Return(bid : Int); // Units will move back to their building [bid]

	/* Economy*/
	Gather(bid : Int, x : Float, y : Float, radius : Float); // Units of [bid] will gather freely in a [radius] around [x, y]
	ConstructAt(bid : Int, x : Float, y : Float, type : Word); // Units of [bid] will start to build a [building] of type (HOUSE|TOWER)] at [x, y]
	Construct(bid : Int, tid : Int); // Units of [bid] will start to help building [tid]

	/* Military */
	Siege(bid : Int, tid : Int); // Units of [bid] will attack building [tid]
	
	Say(bid : Int, onUnit : Int, msg : String); // Displays a [msg] from [bid] (or closest unit to the current targetPoint if [onUnit] == 1)
	End; // Finishes the turn
}

/**
	This system is in charge of handling players orders
*/
class ActionSystem {
	public static function getTurnProfile(state : WarState, pid : PlayerId) : TurnActionProfile<WarAction> {
		var ordered = new Map<Int, Bool>();
		var recruited = new Map<Int, Bool>();
		var said = new Map<Int, Bool>();
		function check(map : Map<Int, Bool>, id, dupErr) {
			var building = state.getBuildingById(id); 
			if (building == null) return Error('Building [$id] does not exists.');
			if (state.getBuildingById(id, pid) == null) return Error('Building [$id] does not belong to [$pid].');

			if (map.exists(id)) return Error(dupErr + ' building [$id] on the same turn.');
			map.set(id, true);
			return Ok(true);
		}
		final checkRecruit = check.bind(recruited, _, 'Cannot recruit multiple units from');
		final checkSay = check.bind(said, _, 'Cannot say multiple messages from');
		final checkOrder = (act, id) -> {
			// @todo check gameplay allows (build/gather for towers, attack for houses)
			final order = Type.enumConstructor(act);
			final data = Data.building.get(state.getBuildingById(id)?.kind);
			if (data != null && !data.canOrder(cast order))
				return Error('${data.kind} [$id] cannot give order $order.');
			return check(ordered, id, 'Cannot give multiple position orders to');
		}

		return Until(
			a -> a.match(End), 
			a -> switch (a) {
				case Recruit(bid, type):
					if (Data.unit.resolve(type.toPascalCase(), true) == null)
						Error('Unknown unit type $type.');
					else checkRecruit(bid);

				case Rally(bid, _, _): checkOrder(a, bid);

				case Return(bid): checkOrder(a, bid);

				case Gather(bid, _, _, _): checkOrder(a, bid);

				case ConstructAt(bid, _, _, type):
					if (Data.building.resolve(type.toPascalCase(), true) == null)
						Error('Unknown building type $type.');
					else checkOrder(a, bid); // @todo check if always possible

				case Construct(bid, tid):
					final target = state.getBuildingById(tid);
					if (target == null)
						Error('Target building [$tid] does not exists.');
					else if (target.owner.get().pid != pid)
						Error('Building [$bid] cannot construct foe building [$tid].');
					else checkOrder(a, bid);

				case Siege(bid, tid):
					final target = state.getBuildingById(tid);
					if (target == null)
						Error('Target building [$tid] does not exists.');
					else if (target.owner.get().pid == pid)
						Error('Building [$bid] cannot attack building of the same camp [$tid].');
					else checkOrder(a, bid);

				case Say(bid, _, _): checkSay(bid);

				case End: Ok(true);
			}		
		);
	}

	public static function apply(state : WarState, actions : PlayersActions<WarAction>) {
		actions.iter( (pid, action, _) -> {
			// At this point, all actions are considered validated by getTurnProfile()
			// Don't need to perform more checks
			switch (action) {
				case Recruit(bid, _.toPascalCase() => type):
					state.getBuildingById(bid).recruit(state, cast type);
				case Rally(bid, x, y):
					state.getBuildingById(bid).order = Rally(new Vec(x, y));
				case Return(bid):
					state.getBuildingById(bid).order = Return;
				case Gather(bid, x, y, radius):
					state.getBuildingById(bid).order = Gather(new Vec(x, y), radius);
				case ConstructAt(bid, x, y, _.toPascalCase() => type):
					state.getBuildingById(bid).order = ConstructAt(new Vec(x, y), cast type);
				case Construct(bid, tid):
					state.getBuildingById(bid).order = Construct(new WeakRef(state.getBuildingById(tid)));
				case Siege(bid, tid):
					state.getBuildingById(bid).order = Siege(new WeakRef(state.getBuildingById(tid)));
				case Say(bid, onUnit, msg):
					state.getBuildingById(bid).say(msg, onUnit > 0);
				case End:
			}
		});

		// Check Say actions expiry
		state.buildings.iter(b -> {
			if (b.sayInfo != null && b.sayInfo.expire-- <= 0)
				b.sayInfo = null;
		});
	}
}