package server.simulation;

import cogpit.utils.Result;
import server.TurnDeferred.TurnCommand;
import server.WarSimulation.TurnContext;
import server.state.Inventory.Resources;
import server.state.WarState.Building;
import server.state.WarState.Clan;
import server.state.WarState.Unit;
import server.state.WarState;

/**
	Operations that can be applied to a building
*/
@:access(server.state.Building)
@:publicFields class BuildingAction {
	
	/**
		The replay will display the text [msg] above the building (or closest unit
		to order target if [onUnit]).
	*/
	static function say(b : Building, msg : String, onUnit : Bool, ctx : TurnContext) {
		if (onUnit) {
			final units = ctx.state.getBuildingUnits(b.bid);
			if (!units.empty()) {
				units[0].replayEvents.push(Said(msg));
				return;
			}
		}
		b.replayEvents.push(Said(msg));
	}

	private static function updateHp(b : Building, v : Int, from : Clan, ctx : TurnContext) : Int {
		final cost = b.getCost();
		final v = hxd.Math.iclamp(b.hp + v, 0, cost) - b.hp;
		b.hp += v;

		if (b.hp == cost && v > 0) { 
			if (b.clan != null) b.kick(ctx); // repairing just finished, only kick workers
			else {
				b.status = Owned(from);
				b.inv.fallbackTo(b.clan.inv);
			}
		}
		else if (b.hp == 0 && v < 0) {
			if (b.clan != null) b.neutralize(ctx); // building was just destroyed
			else b.status = Constructing(from); // construction was canceled by foe, change leading clan on construction
		}

		return v;
	}

	/**
		Simulate one tick of [u] placing a resource in the building hp (construct or repair).
		@return false when the clan does not have enough resources.
	*/
	static function construct(b : Building, u : Unit, ctx : TurnContext) : Bool {
		final clan = u.clan;
		assert(!u.isOrphan);
		assert(b.leading == null || b.leading == clan);
		assert(u.inside(b));

		final cost = Const.ConstructStep;
		if (!clan.inv.has(Materials, cost)) return false;

		final added = b.updateHp(cost, clan, ctx);
		if (added > 0) {
			clan.inv.consume(Materials, added);
			b.replayEvents.push(WasConstructed);
		}
		return true;
	}

	/**
		Simulate one tick of [u] hitting in the building hp (combat unit or worker).
	*/
	static function hit(b : Building, u : Unit, ctx : TurnContext) : Bool {
		assert(!u.isOrphan);
		assert(b.leading != null && b.leading != u.clan);
		assert((b.clan == null) == (u.inside(b))); // Owned buildings must be attacked from outside. Neutral building must be attacked from inside
	
		b.updateHp(-1, u.clan, ctx); // @todo -1 must take [u] stats into account
		b.replayEvents.push(u.inside(b) ? WasHitInside : WasHitOutside);
		u.replayEvents.push(HasAttacked);
		return true;
	}

	/**
		Switch the building back to neutral
	*/
	static function neutralize(b : Building, ctx : TurnContext) {
		b.status = Neutral;
		b.kick(true, ctx);
		b.inv.fallbackTo(null);
	}

	/**
		Kick all units from the building.
		If not [all], garrisoned child units of the building will stay inside.
	*/
	static function kick(b : Building, all = false, ctx : TurnContext) {
		// @todo kick all units from the building
		// @todo redirect workers order
		ctx.state.units.iter(u -> {
			if (!u.inside(b)) return;

			assert(!u.isOrphan);
			if (!all && u.building.get() == b) return;

			ctx.command(UnitLeaveBuilding(u, b, b.pos.clone())); // @todo dispatch poses
			u.replayEvents.push(WasKickedOut(b));
		});
	}

	static function tryRecruit(b : Building, unit : Data.UnitKind, ctx : TurnContext) : Result<haxe.Unit, String> {
		assert(b.clan != null);

		if (!b.data.recruits.exists(r -> r.unitId == unit))
			return Error('${b.kind} [${b.id}] cannot recruit ${unit}s');

		final max = b.data.maxUnits;
		if (ctx.state.getBuildingUnits(b.bid).length >= max)
			return Error('Max unit count $max reached for ${b.kind} [${b.id}]');
		
		final udata = Data.unit.get(unit);
		final res : Resources = udata.cost;
		if (!b.inv.hasAll(res)) // @todo check bravery in building
			return Error('Not enough resources available to recruit ${b.kind} [${b.id}]. Has ${b.clan.inv}, need $res');

		var u = new Unit(unit, b);
		ctx.command(UnitRecruit(u));
		b.replayEvents.push(HasRecruited(u));
		return Ok(Unit);
	}
}