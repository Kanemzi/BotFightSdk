package server.system;

import cogpit.core.GameState.SUID;

import server.behaviour.Behaviour as BH;
import server.behaviour.Behaviour.BehaviourContext;
import server.behaviour.Node.Status;
import server.behaviour.Node.Action;
import server.behaviour.Node.Condition;
import server.state.WarState;
import server.state.WarState.Unit;

@:allow(server.system.UnitBehaviourSystem)
class UnitBehaviourContext extends BehaviourContext {
	final uid : SUID;
	var rnd(default, null) : hxd.Rand;
	var state(default, null) : WarState;
	var unit(default, null) : Unit;

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
	static inline function getContext(unit : Unit, state : WarState, rnd : hxd.Rand) {
		unit.behaviour ??= new UnitBehaviourContext(unit);
		unit.behaviour.unit = state.units.find(u -> u.id == unit.id);
		unit.behaviour.state = state; // Update the state ref for this turn
		unit.behaviour.rnd = rnd;
		return unit.behaviour;
	}

	static final unitBehaviour = BH.fallback([
		action(ctx -> { trace("React to attack"); return Success; }),
		BH.fallback([
			BH.sequence([
				cond(ctx -> ctx.unit.kind == Worker),
				action(ctx -> { trace("Do civilian stuff"); return Running; }),
			]),
			BH.sequence([
				cond(ctx -> ctx.unit.kind == Bruiser),
				action(ctx -> { trace("Do guard stuff"); return Running; }),
			]),
			BH.sequence([
				cond(ctx -> ctx.unit.kind == Hunter),
				action(ctx -> { trace("Do hunter stuff"); return Running; }),
			]),
		], true),
	], true);

	public static function tick(state : WarState, rnd : hxd.Rand) {
		state.units.iter(u -> {
			final ctx = getContext(u, state, rnd);
			unitBehaviour.tick(ctx);
		});
	}
}