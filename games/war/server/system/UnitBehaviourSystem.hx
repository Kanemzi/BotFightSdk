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

@:using(server.system.UnitBehaviourSystem.UnitMemoryUtils)
@:publicFields @:structInit
class UnitMemory {
	@:optional var buildingTarget : Null<Vec>;
	@:optional var wantedTarget : Null<Vec>;
}

class UnitMemoryUtils {
	public static function isTargetDirty(mem : UnitMemory, curTarget : Vec) {
		if ((curTarget == null) != (mem.buildingTarget == null)) return true;
		return !mem.buildingTarget.eq(curTarget);
	}
}

@:allow(server.system.UnitBehaviourSystem)
class UnitBehaviourContext extends BehaviourContext {
	final uid : SUID;
	final bs : UnitBehaviourSystem;
	var unit(default, null) : Unit;
	var turnContext : TurnContext;

	var rnd(get, never) : hxd.Rand;
	inline function get_rnd() return turnContext.rnd;

	var state(get, never) : WarState;
	inline function get_state() return turnContext.state;

	var mem : UnitMemory;

	function new(unit : Unit, bs : UnitBehaviourSystem) {
		super();
		this.uid = unit.id;
		this.bs = bs;
		mem = {};
	}
}

class UnitBehaviourSystem {

	var contexts : Map<Int, UnitBehaviourContext>;

	public function new() {
		contexts = new Map();
	}

	// For typing in wrapped functions
	static inline function action(f : UnitBehaviourContext -> Status) return new Action(cast f);
	static inline function cond(f : UnitBehaviourContext -> Bool) return new Condition(cast f);

	function getContext(unit : Unit, ctx : TurnContext) {
		var b = contexts.get(unit.id);
		if (b == null) {
			b = new UnitBehaviourContext(unit, this);
			contexts.set(unit.id, b);
		}
		if (b.unit != unit) { // Context is dirty
			b.unit = ctx.state.units.find(u -> u.id == unit.id);
			b.turnContext = ctx;
		}
		return b;
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
		final mem = ctx.mem;

		if (u.inside(b)) {
			mem.wantedTarget = null;
			ctx.turnContext.command(UnitLeaveBuilding(u, b, b.pos.clone()));
			return Running;
		}

		final target = b.order.with(Rally(pos) => pos);
		if (mem.isTargetDirty(target)) { // Recompute target
			final memories = ctx.turnContext.state.getBuildingUnits(b.bid)
				.filterMap(u -> {
					final m = ctx.bs.getContext(u, ctx.turnContext).mem;
					return m == mem || m.isTargetDirty(target) ? null : m; 
				});
			ctx.turnContext.log(null, Info, '$memories');
			final wt = MovementSystem.computeTargetSlot(target, u, Const.RallySpread, new Vec());
			mem.buildingTarget = target;
			mem.wantedTarget = wt;
		}
		if (mem.wantedTarget != null)
			ctx.turnContext.command(UnitMoveTo(u, mem.wantedTarget));

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

	function clean(units : ReadOnlyArray<Unit>) {
		for (k => v in contexts) {
			if (!units.exists(u -> u.id == k))
				contexts.remove(k);
		}
	}

	public function tick(ctx : TurnContext) {
		clean(ctx.state.units);
		ctx.state.units.iter(u -> {
			final bctx = getContext(u, ctx);
			unitBehaviour.tick(bctx);
		});
	}
}