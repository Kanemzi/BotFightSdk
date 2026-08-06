package server;

import cogpit.core.GameSimulation.PlayerActions;
import cogpit.core.GameSimulation.PlayersActions;
import cogpit.core.Player.PlayerId;
import cogpit.core.action.Action;
import cogpit.core.action.ActionCollector;
import cogpit.utils.Result;
import server.WarSimulation.TurnContext;
import server.state.WarState;
import server.state.WarState.GroupOrder;

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

@:using(server.WarActions.WarActionExt)
enum WarAction {
	/* All */
	Recruit(bid : Int, type : Word); // Spawn a new unit in [bid]. Cost will depend on the [unit] type
	Garrison(bid : Int); // Units of [bid] will come back inside their building
	Rally(bid : Int, x : Float, y : Float); // Units of [bid] will go and stay stationary around [x, y]

	/* Economy*/
	Gather(bid : Int, x : Float, y : Float, radius : Float); // Units of [bid] will gather freely in a [radius] around [x, y]
	Construct(bid : Int, tid : Int); // Units of [bid] will go inside neutral building [tid] and start claiming or repairing it

	/* Military */
	Siege(bid : Int, tid : Int); // Units of [bid] will attack [tid] to destroy it
	
	Say(bid : Int, onUnit : Int, msg : String); // Displays a [msg] from [bid] (or closest unit to the current targetPoint if [onUnit] == 1)
	End; // Finishes the turn
}

class WarActionExt {
	public static function tryGetBuilding(act : WarAction, c : Clan, state : WarState) : Result<Building, String> {
		return switch (act) {
			case null, End: throw 'Action $act is not related to a building.';
			case Garrison(bid), Rally(bid, _,_), Gather(bid, _,_,_), Construct(bid, _), Siege(bid, _), Recruit(bid, _), Say(bid, _,_):
				final b = state.getBuildingById(bid);
				if (b == null) Error('Building [$bid] does not exists');
				else if (b.clan != c) Error('${b.kind} [${b.id}] does not belong to clan [${c.pid}]');
				else Ok(b);
		}
	}

	public static function tryApply(act : WarAction, c : Clan, ctx : TurnContext) : Result<haxe.Unit, String> {
		function canUseActionType(act : WarAction, b : Building) return switch (b.kind) {
			case House: act.match(Recruit(_,_) | Garrison(_) | Rally(_,_,_) | Gather(_,_,_,_) | Construct(_,_) | Say(_,_,_));
			case Outpost: act.match(Recruit(_,_) | Garrison(_) | Rally(_,_,_) | Siege(_,_) | Say(_,_,_));
			case Laboratory: act.match(Say(_,_,_));
		}

		final state = ctx.state;
		final res = act.tryGetBuilding(c, state);
		if (res.match(Error(_)))
			return res.with(Error(e) => Error(e));

		final b = res.with(Ok(b) => b);
		if (!canUseActionType(act, b))
			return Error('${b.kind} [${b.id}] cannot use ${Type.enumConstructor(act)} actions');

		switch (act) {
			case Recruit(_, _.toPascalCase() => type):
				final tdata = Data.unit.resolve(type.toPascalCase(), true);
				if (tdata == null)
					return Error('Unknown unit type $type');
				final res = b.tryRecruit(tdata.kind, ctx);
				if (res.match(Error(_)))
					return res;

			case Garrison(_):
				b.order = act.toGroupOrder(state);

			case Rally(_, x, y):
				b.order = act.toGroupOrder(state);

			case Gather(_, x, y, radius):
				b.order = act.toGroupOrder(state);

			case Construct(_, tid):
				final target = state.getBuildingById(tid);
				if (target == null)
					return Error('Target building [$tid] does not exists');
				else if (target.clan != null && target.clan != b.clan)
					return Error('${b.kind} [${b.id}] cannot construct foe building [$tid]');
				b.order = act.toGroupOrder(state);

			case Siege(_, tid):
				final target = state.getBuildingById(tid);
				if (target == null)
					return Error('Target building [$tid] does not exists');
				else if (target.clan == null)
					return Error('${b.kind} [${b.id}] cannot attack neutral ${target.kind} [$tid]');
				else if (target.clan.pid == c.pid) // @todo ally clans check
					return Error('${b.kind} [${b.id}] cannot attack ${target.kind} of its own clan [$tid]');
				b.order = act.toGroupOrder(state);

			case Say(_, _ > 0 => onUnit, msg):
				b.say(msg, onUnit, ctx);
			case End:
		}
		return Ok(Unit);
	}

	public static function toGroupOrder(act : WarAction, state : WarState) : GroupOrder return switch (act) {
		case Garrison(_): Garrison;
		case Rally(_, x, y): Rally(new Vec(x, y)); // @todo clamp closest edge if outside the map
		case Gather(_, x, y, radius): Gather(new Vec(x, y), radius); // @todo clamp closest edge if outside the map
		case Construct(_, tid): Construct(state.getBuildingById(tid));
		case Siege(_, tid): Siege(state.getBuildingById(tid));
		case Recruit(_,_), Say(_,_,_), End: throw '${Type.enumConstructor(act)} is not a group order.';
	}
}

/**
	This system is in charge of handling players orders
*/
class WarActions {
	public static function getTurnProfile(state : WarState, pid : PlayerId) : TurnActionProfile<WarAction> {
		var ordered = new Map<Int, Bool>();
		var recruited = new Map<Int, Bool>();
		var said = new Map<Int, Bool>();

		function check(map : Map<Int, Bool>, id, dupErr) : Result<haxe.Unit, String> {
			if (map.exists(id)) return Error(dupErr + ' building [$id] on the same turn.');
			map.set(id, true);
			return Ok(Unit);
		}

		final checkRecruit = check.bind(recruited, _, 'Cannot recruit multiple units from');
		final checkSay = check.bind(said, _, 'Cannot say multiple messages from');
		final checkOrder = check.bind(ordered, _, 'Cannot give multiple position orders to');

		return Until(
			a -> a.match(End), 
			a -> switch (a) {
				case Recruit(bid, _): checkRecruit(bid);
				case Garrison(bid), Rally(bid, _,_), Gather(bid, _,_,_), Construct(bid, _), Siege(bid, _): checkOrder(bid);
				case Say(bid, _,_): checkSay(bid);
				case End: Ok(Unit);
			}
		);
	}

	public static function apply(actions : PlayersActions<WarAction>, ctx : TurnContext) {
		final state = ctx.state;
		actions.iter( (pid, action, _) -> if (!action.match(End)) {
			final clan = state.getClan(pid);
			action.tryApply(clan, ctx)
				.with(Error(e) => {
					final as = ActionParser.toString(action); 
					ctx.log(pid, Error, 'Action "$as" failed : $e.');
				});
		});
	}
}