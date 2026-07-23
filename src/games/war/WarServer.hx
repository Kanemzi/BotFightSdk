package games.war;

import core.GameServer;
import core.Player;
import core.TurnModel;
import core.action.ActionCollector;

import games.war.WarState;
import games.war.view.WarViewer;

class WarServer extends GameServer<WarState, WarAction> {

	public function new(seed : Int) {
		super(seed, {
			version : 1,
			minPlayers : 2,
			maxPlayers : 2,
			maxTurns : 10,
			firstTurnTimeout : 1000.0,
			turnTimeout : 1000.0,
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