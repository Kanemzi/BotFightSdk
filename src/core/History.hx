package core;

import core.action.Action;
import core.action.ActionsResult;
import core.Player.PlayerId;

@:generic
class HistoryTurn<Ts : GameState, Ta : Action> implements hxbit.Serializable {
	@:s @:noPrivateAccess var actions : Array<ActionsResult<Ta>>;
	@:s @:noPrivateAccess var _state : GameState;
    // @todo if I use the authority system, GameServer.update() function will need to be aware of player state (alive, defeated, ...) 

	public function new(state : Ts, actions : Array<ActionsResult<Ta>>) {
		this.actions = actions;
		_state = state;
	}

	public var state(get, never) : Ts;
	function get_state() return cast _state;
}

@:publicFields
class HistoryPlayer implements hxbit.Serializable {
	@:s var rank : Int;
	public function new(rank : Int) {
		this.rank = rank;
	}
}

@:publicFields @:generic
class History<Ts : GameState, Ta : Action> implements hxbit.Serializable {
	@:s var version : String;
	@:s var players : Map<PlayerId, HistoryPlayer>;
	@:s var turns : Array<HistoryTurn<Ts, Ta>>;
	
	var length(get, never) : Int;
	function get_length() return turns.length;

	function new(v : String, players : Array<Player<Ta>>) {
		version = v;
		this.players = [for (p in players) p.id => new HistoryPlayer(-1)];
		turns = [];
	}

	function addTurn(actions : Array<ActionsResult<Ta>>, state : Ts) {
		turns.push(new HistoryTurn(state, actions));
	}
}