package server;

import server.WarSimulation.TurnContext;
import server.state.WarState.Building;
import server.state.WarState.Unit;
import server.state.WarState.Vec;
import server.system.MovementSystem;

using server.TurnDeferred;

/**
	Commands that will be deferred to the end of the turn simulation to avoid conflicts or
	any advantage due to systems iteration order.
**/
enum TurnCommand {
	@priority(500) UnitFlee(u : Unit);
	@priority(100) UnitRecruit(u : Unit);
	@priority(50) UnitLeaveBuilding(u : Unit, b : Building, p : Vec);
	@priority(10) UnitEnterBuilding(u : Unit, b : Building);
	@priority(1) UnitMoveTo(u : Unit, p : Vec);
}

class TurnDeferred {

	/**
		Queue a new command for the end of the turn
	**/
	public static function command(ctx : TurnContext, cmd : TurnCommand) {
		final prio = cmd.getPriority();
		final unit = cmd.getUnit();

		var foundBetter = false;
		ctx.commands.keep(c -> {
			if (unit == null || c.getUnit() != unit) return true;
			var better = c.getPriority() > prio;
			foundBetter = foundBetter || better;
			return better;
		});

		if (foundBetter) return;

		ctx.commands.push(cmd);
	}

	/**
		Apply all commands that were queued this turn to the state
	**/
	public static function apply(ctx : TurnContext) {
		final commands = ctx.commands;
		final state = ctx.state;

		commands.keep(c -> !c.with(UnitFlee(u) => {
			assert(state.units.contains(u));
			state.units.remove(u);
			true;
		}));

		commands.keep(c -> !c.with(UnitRecruit(u) => {
			assert(!state.units.contains(u));
			state.units.push(u);
			true;
		}));

		commands.keep(c -> !c.with(UnitLeaveBuilding(u, b, pos) => {
			assert(state.units.contains(u));
			assert(u.inside(b));
			u.pos = Terrain(pos.clone());
			true;
		}));

		commands.keep(c -> !c.with(UnitEnterBuilding(u, b) => {
			assert(state.units.contains(u));
			assert(!u.inside());
			u.pos = Building(b.bid);
			true;
		}));

		commands.keep(c -> !c.with(UnitMoveTo(u, p) => {
			assert(state.units.contains(u));
			assert(!u.inside());
			final next = MovementSystem.resolveStep(u, p);
			if (next != null)
				u.pos.with(Terrain(pos) => {
					pos.x = next.x;
					pos.y = next.y;
				});
			true;
		}));

		assert(commands.empty(), 'Some deferred commands were not processed during this turn : $commands');
	}

	@:pure public static function getUnit(cmd : TurnCommand) : Unit {
		return cmd.with(UnitRecruit(u) | UnitFlee(u) | UnitEnterBuilding(u, _) | UnitLeaveBuilding(u, _,_) | UnitMoveTo(u, _) => u);
	}

	@:pure public static function getPriority(cmd : TurnCommand) : Int {
		final c = Type.enumConstructor(cmd);
		final f = haxe.rtti.Meta.getFields(TurnCommand); 
		final meta = Reflect.field(f, c);
		return meta.priority[0];
	}
}