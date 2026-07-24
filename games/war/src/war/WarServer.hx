package war;

import botfight.core.GameServer;
import botfight.core.Player;
import botfight.core.TurnModel;
import botfight.core.action.ActionCollector;

import war.WarState;
import war.view.WarViewer;

class WarServer extends GameServer<WarState, WarAction> {

	public function new(seed : Int) {
		super(seed, {
			version : 1,
			minPlayers : 2,
			maxPlayers : 2,
			maxTurns : 10,
			firstTurnTimeout : 1.0,
			turnTimeout : 0.5,
			turnModel : TurnModel.SimultaneousTurn,
		});
	}

	function init() : WarState {
		return new WarState(players.map(p -> p.id), seed);
	}

	function update(state : WarState, actions : PlayersActions<WarAction>) : Void {
	}

	function getTurnActionProfile(pid : PlayerId) return Fixed(1);

	function getTiebreakerScore(pid : PlayerId) : Int {
		return 0;
	}

	public static function main() {
		new Runner(WarServer, WarViewer, Sys.args());
	}
}