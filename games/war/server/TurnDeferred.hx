package server;

import server.WarSimulation.TurnContext;
import server.state.WarState.Building;
import server.state.WarState.Unit;
import server.state.WarState.Vec;

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
	@priority(1) UnitMove(u : Unit, p : Vec);
}

class TurnDeferred {

	/**
		Queue a new command for the end of the turn
	**/
	public static function command(ctx : TurnContext, cmd : TurnCommand) {
		ctx.assertCommand(cmd);

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
		Ensure the command is valid. Using asserts since these situations should not
		happen if the system pushing it is correct.
	**/
	static function assertCommand(ctx : TurnContext, cmd : TurnCommand) {
		final state = ctx.state;
		switch (cmd) {
			case UnitRecruit(u): assert(!state.units.contains(u));
			case UnitFlee(u): assert(state.units.contains(u));
			case UnitEnterBuilding(u, b): assert(!u.inside()); // @todo can't if flee
			case UnitLeaveBuilding(u, b, p): assert(u.inside(b)); // @todo can't if flee
			case UnitMove(u, p): assert(!u.inside()); // @todo can't if flee || enter
		}
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

		commands.keep(c -> !c.with(UnitMove(u, p) => {
			assert(state.units.contains(u));
			assert(!u.inside());
			u.pos.with(Terrain(pos) => {
				pos.x = p.x;
				pos.y = p.y;
			});
			true;
		}));

		assert(commands.empty(), 'Some deferred commands were not processed during this turn : $commands');
	}

	@:pure public static function getUnit(cmd : TurnCommand) : Unit {
		return cmd.with(UnitRecruit(u) | UnitFlee(u) | UnitEnterBuilding(u, _) | UnitLeaveBuilding(u, _,_) | UnitMove(u, _) => u);
	}

	@:pure public static function getPriority(cmd : TurnCommand) : Int {
		final c = Type.enumConstructor(cmd);
		final f = haxe.rtti.Meta.getFields(TurnCommand); 
		final meta = Reflect.field(f, c);
		return meta.priority[0];
	}
}