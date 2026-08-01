package cogpit.core;

import cogpit.core.action.Action;
import cogpit.core.Player.PlayerId;

interface TurnModel {
	public function getPlayingThisTurn(players : ReadOnlyArray<PlayerId>, state : GameState, turn : Int) : ReadOnlyArray<PlayerId>;
}

class SequentialTurn implements TurnModel {
	// @todo when a player is killed, another player might play twice with this strategy
	public function getPlayingThisTurn(players : ReadOnlyArray<PlayerId>, state : GameState, turn : Int) : ReadOnlyArray<PlayerId> {
		return [players[turn % players.length]];
	}
}

class SimultaneousTurn implements TurnModel {
	public function getPlayingThisTurn(players : ReadOnlyArray<PlayerId>, state : GameState, turn : Int) : ReadOnlyArray<PlayerId> {
		return players;
	}
}