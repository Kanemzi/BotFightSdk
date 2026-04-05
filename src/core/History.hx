package core;

import core.action.Action;
import core.action.ActionsResult;
import core.Player.PlayerId;

enum PlayerOutcome {
	Defeat(turn : Int, ?tiebreak : Int);
	Victory(turn : Int, ?tiebreak : Int);
	Draw(turn : Int, tiebreak : Int);
}

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
	@:s var outcome : Null<PlayerOutcome>;
	public function new() {
		outcome = null;
	}
}

@:generic
@:allow(History)
class History<Ts : GameState, Ta : Action> implements hxbit.Serializable {
	@:s public var version : String;
	@:s public var players : Map<PlayerId, HistoryPlayer>;
	@:s public var turns : Array<HistoryTurn<Ts, Ta>>;
	
	public var length(get, never) : Int;
	function get_length() return turns.length;
	
	@:noPrivateAccess var completed : Bool = true;

	public function new(v : String, players : Array<Player<Ta>>) {
		version = v;
		this.players = [for (p in players) p.id => new HistoryPlayer()];
		turns = [];
		completed = false;
	}

	public function addTurn(state : Ts, actions : Array<ActionsResult<Ta>>) {
		if (completed)
			throw 'Can\'t add new turns to a locked history';
		turns.push(new HistoryTurn(state, actions));
	}

	public function outcome(pid : PlayerId, out : PlayerOutcome) {
		if (completed)
			throw 'Can\'t add outcomes to a locked history';
		var hp = players.get(pid);
		if (hp.outcome != null)
			throw 'An outcome was already registered for player $pid';
		hp.outcome = out;
	}

	public function lock() { completed = true; }

	public function getDefeatTurn(pid : PlayerId) {
		
	}
}