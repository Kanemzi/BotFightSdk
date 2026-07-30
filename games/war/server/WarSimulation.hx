package server;

import botfight.core.GameSimulation;
import botfight.core.GameSimulation.PlayersActions;
import botfight.core.TurnModel;
import botfight.core.action.ActionCollector;
import botfight.core.Player.PlayerId;

import server.WarState;
import server.system.ActionSystem;
import server.system.MovementSystem;
import view.WarViewer;

class WarSimulation extends GameSimulation<WarState, WarAction> {

	function init(ctx : InitContext<WarAction>) : WarState {
		return new WarState(ctx.getPlayers(), ctx.rnd);
	}

	function update(state : WarState, ctx : SimulationContext<WarAction>) : Void {
		ActionSystem.apply(state, ctx.actions);
		MovementSystem.tick(state);
	}

	function getTurnActionProfile(state : WarState, pid : PlayerId) : TurnActionProfile<WarAction> {
		return ActionSystem.getTurnProfile(state, pid);
	}

	function getTiebreakerScore(state : WarState, pid : PlayerId) : Int {
		return state.getPlayerUnits(pid).length; // @todo use extensions to keep the state as empty as possible
	}

	function serializeHeaderForPlayer(initialState : WarState, pid : PlayerId) : Array<String> {
		return ['$pid'];
	}

	function serializeForPlayer(state : WarState, pid : PlayerId) : Array<String> {
		return [];
	}

	public static function main() {
		hxd.Res.initLocal();
		Data.load(hxd.Res.data.entry.getText());
		new botfight.Runner(WarSimulation, WarViewer, Sys.args(), {
			version : 1,
			maxTurns : 10,
			firstTurnTimeout : 1.0,
			turnTimeout : 0.5,
			turnModel : TurnModel.SimultaneousTurn,
			storageMode : Deterministic,
		});
	}
}