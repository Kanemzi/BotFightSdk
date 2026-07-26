package botfight.core;

import botfight.core.action.Action;
import botfight.core.action.ActionsResult;
import botfight.core.Player.PlayerId;
import botfight.core.Storage;

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

@:publicFields @:structInit
class HistoryHeader implements hxbit.Serializable {
	@:s var version : Int;
	@:s var seed : Int;
	@:s var format : StorageMode;
}

@:generic
@:allow(History)
class History<Ts : GameState, Ta : Action> implements hxbit.Serializable {
	@:s public var header(default, null) : HistoryHeader;
	@:s public var players(default, null) : Map<PlayerId, HistoryPlayer>;
	@:s public var turns(default, null) : Array<HistoryTurn<Ts, Ta>>;
	
	public var length(get, never) : Int;
	function get_length() return turns.length;
	
	@:noPrivateAccess var completed : Bool = true;

	public function new(v : Int, players : Array<Player<Ta>>, seed : Int) {
		header = {
			version : v,
			seed : seed,
			format : Full,
		}
		this.players = [for (p in players) p.id => new HistoryPlayer()];
		turns = [];
		completed = false;
	}

	public function addTurn(state : Ts, actions : Array<ActionsResult<Ta>>) {
		if (completed)
			throw 'Cannot add new turns to a locked history';
		turns.push(new HistoryTurn(state, actions));
	}

	public function outcome(pid : PlayerId, out : PlayerOutcome) {
		if (completed)
			throw 'Cannot add outcomes to a locked history';
		var hp = players.get(pid);
		if (hp.outcome != null)
			throw 'An outcome was already registered for player $pid';
		hp.outcome = out;
	}

	public function lock() {
		completed = true;
		return this;
	}

	public function optimize<Ts : GameState, Ta : Action>(?format : StorageMode) {
		if (!completed)
			throw 'Cannot optimize an history that is not locked yet';

		switch (format ?? header.format) {
			case Full:
			case Delta: for (i in 0...length) {
				var prev = turns[i - 1]?.state;
				var next = turns[i].state;
				next.optimizeDelta(prev);
			}
			case Deterministic: // @todo implement
		}
	}

	public inline function getStateUID() return turns[0].state.id;
}