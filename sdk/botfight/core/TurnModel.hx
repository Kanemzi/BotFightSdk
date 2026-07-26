package botfight.core;

import botfight.core.action.Action;
import botfight.core.Player.PlayerId;

interface TurnModel {
	public function getPlayingThisTurn(players : Array<PlayerId>, state : GameState, turn : Int) : Array<PlayerId>;
}

class SequentialTurn implements TurnModel {
	// @todo when a player is killed, another player might play twice with this strategy
	public function getPlayingThisTurn(players : Array<PlayerId>, state : GameState, turn : Int) : Array<PlayerId> {
		return [players[turn % players.length]];
	}
}

class SimultaneousTurn implements TurnModel {
	public function getPlayingThisTurn(players : Array<PlayerId>, state : GameState, turn : Int) : Array<PlayerId> {
		return players;
	}
}