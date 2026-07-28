package server;

import botfight.core.GameSimulation;
import botfight.core.GameSimulation.PlayersActions;
import botfight.core.TurnModel;
import botfight.core.action.ActionCollector;
import botfight.core.Player.PlayerId;

import server.WarState;
import view.WarViewer;

class WarSimulation extends GameSimulation<WarState, WarAction> {

	function init(players : ReadOnlyArray<PlayerId>, rnd : hxd.Rand) : WarState {
		return new WarState(players, rnd);
	}

	function update(state : WarState, ctx : SimulationContext<WarAction>) : Void {
	}

	function getTurnActionProfile(state : WarState, pid : PlayerId) return Fixed(1); // @todo
	function getTiebreakerScore(state : WarState, pid : PlayerId) : Int return 0;

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
			minPlayers : 2,
			maxPlayers : 2,
			maxTurns : 10,
			firstTurnTimeout : 1.0,
			turnTimeout : 0.5,
			turnModel : TurnModel.SimultaneousTurn,
			storageMode : Deterministic,
		});
	}
}