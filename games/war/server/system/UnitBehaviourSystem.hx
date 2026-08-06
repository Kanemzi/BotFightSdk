package server.system;

import cogpit.core.GameState.SUID;
import server.TurnDeferred.TurnCommand;
import server.WarSimulation.TurnContext;
import server.behaviour.Behaviour as BH;
import server.behaviour.Behaviour.BehaviourContext;
import server.behaviour.Node.Action;
import server.behaviour.Node.Condition;
import server.behaviour.Node.Status;
import server.state.WarState.Building;
import server.state.WarState.Unit;
import server.state.WarState.Vec;
import server.state.WarState;

@:allow(server.system.UnitBehaviourSystem)
class UnitBehaviourContext extends BehaviourContext {
	final uid : SUID;
	var unit(default, null) : Unit;
	var turnContext : TurnContext;

	var rnd(get, never) : hxd.Rand;
	inline function get_rnd() return turnContext.rnd;

	var state(get, never) : WarState;
	inline function get_state() return turnContext.state;

	function new(unit : Unit) {
		super();
		this.uid = unit.id;
	}
}

class UnitBehaviourSystem {

	// For typing in wrapped functions
	static inline function action(f : UnitBehaviourContext -> Status) return new Action(cast f);
	static inline function cond(f : UnitBehaviourContext -> Bool) return new Condition(cast f);

	@:access(server.Unit) // Should remain the only way to retrieve a context, to ensure it's initialized correctly for this turn
	static inline function getContext(unit : Unit, ctx : TurnContext) {
		unit.behaviour ??= new UnitBehaviourContext(unit);
		unit.behaviour.unit = ctx.state.units.find(u -> u.id == unit.id);
		unit.behaviour.turnContext = ctx;
		return unit.behaviour;
	}

	static function garrisonBehaviour(ctx : UnitBehaviourContext) : Status {
		final u = ctx.unit;
		final b = u.building.get();
		if (u.inside(b))
			return Success;

		if (MovementSystem.hasArrived(u, b.pos)) {
			ctx.turnContext.command(UnitEnterBuilding(u, b));
			ctx.turnContext.log(u.clan?.pid, Info, 'Unit [${u.id}] entered garrison in ${b.kind} [${b.id}].');
		} else
			ctx.turnContext.command(UnitMoveTo(u, b.pos));
		return Running;
	}

	static function rallyBehaviour(ctx : UnitBehaviourContext) : Status {
		final u = ctx.unit;
		final b = u.building.get();

		if (u.inside(b)) {
			ctx.turnContext.command(UnitLeaveBuilding(u, b, b.pos.clone()));
			return Running;
		}

		final target = b.order.with(Rally(pos) => pos);
		ctx.turnContext.command(UnitMoveTo(u, MovementSystem.computeTargetSlot(target, u, Const.RallySpread, new Vec())));
		return Running;
	}

	static final unitBehaviour = BH.fallback([
		BH.sequence([
			cond(ctx -> ctx.unit.data.behaviourId == Worker),
			BH.fallback([
				BH.sequence([cond(ctx -> ctx.unit.building.get().order.match(Garrison)), action(garrisonBehaviour)]),
				BH.sequence([cond(ctx -> ctx.unit.building.get().order.match(Rally(_))), action(rallyBehaviour)]),
			], true),
		]),
	], true);

	public static function tick(ctx : TurnContext) {
		ctx.state.units.iter(u -> {
			final bctx = getContext(u, ctx);
			unitBehaviour.tick(bctx);
		});
	}
}