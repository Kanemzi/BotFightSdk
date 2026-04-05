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
			firstTurnTimeout : 1000.0,
			turnTimeout : 1000.0,
			turnModel : TurnModel.SimultaneousTurn,
		});
	}

	function init() : WarState {
        return new WarState(players.length, seed);
	}

	function update(state : WarState, actions : Array<PlayerActions<WarAction>>) : Void {
	}

	function serializeStateForPlayer(pid : PlayerId) : Array<String> {
        return [];
	}

	function getTurnActionProfile(pid : PlayerId) return Fixed(1);

	function getTiebreakerScore(pid : PlayerId) : Int {
		return 0;
	}


	public static function main() {
		new Runner(WarServer, Sys.args());
	}
}