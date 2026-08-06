package server;

import client.WarClient;
import cogpit.core.GameServer.LogSeverity;
import cogpit.core.GameSimulation.PlayersActions;
import cogpit.core.GameSimulation;
import cogpit.core.Player.PlayerId;
import cogpit.core.TurnModel;
import cogpit.core.action.ActionCollector;
import server.TurnDeferred.TurnCommand;
import server.TurnDeferred;
import server.WarActions;
import server.state.WarState;
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

	// Hook for logging info to the replay from any system
	public var log(default, null) : (Null<PlayerId>, LogSeverity, String) -> Void;

	@:allow(server.TurnDeferred)
	var commands : Array<TurnCommand> = [];

	public function new() {}

	@:allow(server.WarSimulation)
	function init(state, ctx) {
		this.state = state;
		this.turn = ctx.turn;
		this.rnd = ctx.rnd;
		this.log = ctx.log;
	}
}

class WarSimulation extends GameSimulation<WarState, WarAction> {

	var turnContext = new TurnContext();

	function init(ctx : InitContext<WarAction>) : WarState {
		return new WarState(ctx.getPlayers(), ctx.rnd);
	}

	function update(state : WarState, ctx : SimulationContext<WarAction>) : Void {
		turnContext.init(state, ctx);

		WarActions.apply(ctx.actions, turnContext);
		
		ReplaySystem.tick(turnContext);
		UnitBehaviourSystem.tick(turnContext);

		TurnDeferred.apply(turnContext);
	}

	function getTurnActionProfile(state : WarState, pid : PlayerId) : TurnActionProfile<WarAction> {
		return WarActions.getTurnProfile(state, pid);
	}

	function getTiebreakerScore(state : WarState, pid : PlayerId) : Int {
		return state.getClanUnits(pid).length; // @todo use extensions to keep the state as empty as possible
	}

	function serializeHeaderForPlayer(initialState : WarState, pid : PlayerId) : Array<String> {
		return ['$pid', '${Const.Width} ${Const.Height}'];
	}

	function serializeForPlayer(state : WarState, pid : PlayerId) : Array<String> {
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

		return ['BUILDING ${state.buildings.length}']
			.concat(state.buildings.map(serializeBuilding))
			.concat(['UNIT ${state.units.length}'])
			.concat(state.units.map(serializeUnit));
	}

	public static function main() {
		hxd.Res.initLocal();
		Data.load(hxd.Res.data.entry.getText());
		new cogpit.Runner(WarSimulation, WarClient, Sys.args(), {
			version : 1,
			maxTurns : 400,
			firstTurnTimeout : 1.0,
			turnTimeout : 0.5,
			turnModel : TurnModel.SimultaneousTurn,
			storageMode : Deterministic,
		});
	}
}