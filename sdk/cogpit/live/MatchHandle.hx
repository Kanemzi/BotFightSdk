package cogpit.live;

import cogpit.core.GameState;
import cogpit.core.action.Action;
import cogpit.Match;


/**
	Thread safe interface for the client to read match info
*/
@:access(cogpit.Match)
@:forward(seed, toString)
abstract MatchHandle<Ts : GameState, Ta : Action>(Match<Ts, Ta>) from Match<Ts, Ta> {
	public var games(get, never) : Array<GameSlot<Ts, Ta>>;
	inline function get_games() {
		this.liveMut.acquire();
		var g = this.games.copy();
		this.liveMut.release();
		return g;
	}
}