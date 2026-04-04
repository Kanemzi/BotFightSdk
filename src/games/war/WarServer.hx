package games.war;

import core.GameServer;
import core.Player;
import core.TurnModel;
import core.action.ActionCollector;

import games.war.WarState;

class WarServer extends GameServer<WarState, WarAction> {
	public static inline final WIDTH = 16;
	public static inline final HEIGHT = 7;
	public static inline final START_ENERGY = 10;

	public function new(seed : Int) {
		super(seed, {
			version : "0.1",
			minPlayers : 2,
			maxPlayers : 2,
			maxTurns : 10,
			firstTurnTimeout : 100000,
			turnTimeout : 100000,
			turnModel : TurnModel.SimultaneousTurn,
		});
	}

	function init() : WarState {
        return new WarState(players.length, seed);
	}

	function update(state : WarState) : Void {
	}

	function serializeStateForPlayer(player : Player<WarAction>) : Array<String> {
        return [];
	}

	public function getTurnActionProfile(player : Player<WarAction>) return Fixed(1);

	public static function main() {
		new Runner(WarServer, Sys.args());
	}
}