package server;

import client.WarClient;
import cogpit.core.GameSimulation.PlayersActions;
import cogpit.core.GameSimulation;
import cogpit.core.Player.PlayerId;
import cogpit.core.TurnModel;
import cogpit.core.action.ActionCollector;
import server.state.WarState;
import server.WarActions;
import server.TurnDeferred.TurnCommand;
import server.TurnDeferred;
import server.system.MovementSystem;
import server.system.ReplaySystem;
import server.system.UnitBehaviourSystem;

/**
	Used to pass all useful game data to systems in one paremeters
	Also registers deferred commands that will affect the state in late simulation passes
**/

@:using(server.TurnDeferred)
class TurnContext {
	public var state(default, null) : WarState;
	public var turn(default, null) : Int;
	public var rnd(default, null) : hxd.Rand;

	@:allow(server.TurnDeferred)
	var commands : Array<TurnCommand> = [];

	public function new() {}

	@:allow(server.WarSimulation)
	function init(state, turn, rnd) {
		this.state = state;
		this.turn = turn;
		this.rnd = rnd;
	}
}

class WarSimulation extends GameSimulation<WarState, WarAction> {

	var turnContext = new TurnContext();

	function init(ctx : InitContext<WarAction>) : WarState {
		return new WarState(ctx.getPlayers(), ctx.rnd);
	}

	function update(state : WarState, ctx : SimulationContext<WarAction>) : Void {
		turnContext.init(state, ctx.turn, ctx.rnd);

		WarActions.apply(ctx.actions, turnContext);
		
		ReplaySystem.tick(turnContext);
		UnitBehaviourSystem.tick(turnContext);
		MovementSystem.tick(turnContext);
		
		TurnDeferred.apply(turnContext);
	}

	function getTurnActionProfile(state : WarState, pid : PlayerId) : TurnActionProfile<WarAction> {
		return WarActions.getTurnProfile(state, pid);
	}

	function getTiebreakerScore(state : WarState, pid : PlayerId) : Int {
		return state.getClanUnits(pid).length; // @todo use extensions to keep the state as empty as possible
	}

	function serializeHeaderForPlayer(initialState : WarState, pid : PlayerId) : Array<String> {
		return ['$pid'];
	}

	function serializeForPlayer(state : WarState, pid : PlayerId) : Array<String> {
		// @todo players need confirmation that their order was taken into account
		// @todo give unit ids for micro decisions & better tracking ?
		/*
			PLAYER [PID] [FOOD] [WOOD] (n following lines) 
			BUILDING : [BID] [T|H] [PID | -1] [X] [Y] @todo info de construction, avancée
			UNIT : [UID] [C|G|H] [BID | -1] ([G] [BID] | [X] [Y]) @todo hp, combat target
			RES : [W|F] [AMOUNT] [X] [Y]
		
			[PLAYER]
			...
			[BUILDING]
			... 
			[UNIT]
			...
			[RES]
			...
		*/
		
		function serializeResource(r : Resource) {
			final kind = r.kind.toString().charAt(0);
			return '$kind ${r.amount} ${r.pos.x} ${r.pos.y}';
		}

		function serializeUnit(u : Unit) {
			final kind = u.kind.toString().charAt(0);
			final pos = switch(u.pos) {
				case Building(bid): 'G $bid';
				case Terrain(pos): '${pos.x} ${pos.y}';
			}
			final building = u.building.get()?.bid ?? -1;
			return '${u.id} $kind $building $pos';
		}

		function serializeBuilding(b : Building) {
			final kind = b.kind.toString().charAt(0);
			var clan = b.clan?.pid ?? -1; 
			return '${b.bid} $kind $clan ${b.pos.x} ${b.pos.y}';
		}

		function serializeClan(p : Clan) {
			return '${p.pid} ${p.inv.get(Food)} ${p.inv.get(Materials)}';
		}

		final clan = state.getClan(pid);
		var clans = state.clans.filter(p -> p.pid != pid);
		clans.unshift(clan);
		return (clans.map(serializeClan))
			.concat(state.buildings.map(serializeBuilding))
			.concat(state.units.map(serializeUnit))
			.concat(state.resources.map(serializeResource));
	}

	public static function main() {
		hxd.Res.initLocal();
		Data.load(hxd.Res.data.entry.getText());
		new cogpit.Runner(WarSimulation, WarClient, Sys.args(), {
			version : 1,
			maxTurns : 10,
			firstTurnTimeout : 1.0,
			turnTimeout : 0.5,
			turnModel : TurnModel.SimultaneousTurn,
			storageMode : Deterministic,
		});
	}
}