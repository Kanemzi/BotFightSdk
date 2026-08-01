package botfight.live;

import botfight.core.GameState;
import botfight.core.action.Action;
import botfight.Match;


/**
	Thread safe interface for the client to read match info
*/
@:access(botfight.Match)
@:forward(seed, toString)
abstract MatchHandle<Ts : GameState, Ta : Action>(Match<Ts, Ta>) from Match<Ts, Ta> {
	public var games(get, never) : Array<GameSlot<Ts, Ta>>;
	inline function get_games() {
		this.mut.acquire();
		var g = this.games.copy();
		this.mut.release();
		return g;
	}
}