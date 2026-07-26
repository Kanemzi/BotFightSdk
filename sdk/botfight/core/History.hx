package botfight.core;

import botfight.core.action.Action;
import botfight.core.action.ActionsResult;
import botfight.core.Player.PlayerId;
import botfight.core.Storage;
import botfight.core.GameSimulation;
import botfight.core.GameSimulation.SimulationContext;

enum PlayerOutcome {
	Defeat(turn : Int, ?tiebreak : Int);
	Victory(turn : Int, ?tiebreak : Int);
	Draw(turn : Int, tiebreak : Int);
}

@:generic @:allow(botfight.core.History)
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

	public function optimize(format : StorageMode) {
		if (!completed)
			throw 'Cannot optimize an history that is not locked yet.';
		if (header.format != Full)
			throw 'Cannot optimize an history twice.';

		switch (format) {
			case Full:
				return;
			case Delta: for (i in 0...length) {
				var prev = turns[i - 1]?.state;
				var next = turns[i].state;
				next.optimizeDelta(prev);
			}
			case Deterministic:
				for (t in turns) t._state = null;
		}

		header.format = format;
	}

	public function getAlivePlayers(?turn : Int) : Array<PlayerId> {
		return [for (i => p in players) {
			final alive = switch (p.outcome) {
				case null : true;
				case Defeat(t, _), Victory(t, _), Draw(t, _) if (turn != null && turn < t): true;
				default: false;
			}
			if (alive) i;
		}];
	}

	@:access(botfight.core.GameSimulation)
	@:access(botfight.core.SimulationContext)
	public function recover(cl : Class<GameSimulation<Ts, Ta>>) {
		if (turns.length == 0) return;
		switch (header.format) {
			case Full, Delta:
			case Deterministic: // resimulate the whole game based on registered player actions
				var sim = Type.createInstance(cl, []);
				final players = getAlivePlayers(0);
				var initState = sim.init(players, new hxd.Rand(header.seed));
				turns[0]._state = initState;
				for (t in 1...turns.length) {
					final alive = getAlivePlayers(t);
					final actions = ActionsResult.toPlayersActions(turns[t].actions);
					final turnSeed = header.seed + t + 1;
					var newState = GameServer.cloneState(turns[t - 1].state);
					var ctx = new SimulationContext(actions, alive, turnSeed);
					sim.update(newState, ctx);
					turns[t]._state = newState;
				}
		}
	}

	public inline function getStateUID() return turns[0].state.id;
}