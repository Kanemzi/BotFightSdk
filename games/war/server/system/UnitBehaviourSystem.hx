package server.system;

import cogpit.core.GameState.SUID;
import server.WarSimulation.TurnContext;
import server.behaviour.Behaviour as BH;
import server.behaviour.Behaviour.BehaviourContext;
import server.behaviour.Node.Action;
import server.behaviour.Node.Condition;
import server.behaviour.Node.Status;
import server.state.WarState.Unit;
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

	static final unitBehaviour = BH.fallback([
		BH.fallback([
			BH.sequence([
				cond(ctx -> ctx.unit.data.behaviourId == Worker),
				action(ctx -> { trace("Do civilian stuff"); return Running; }),
			]),
		], true),
	], true);

	public static function tick(ctx : TurnContext) {
		ctx.state.units.iter(u -> {
			final bctx = getContext(u, ctx);
			unitBehaviour.tick(bctx);
		});
	}
}