package botfight.core;

import botfight.core.History;
import botfight.core.GameSimulation.PlayersActions;
import botfight.core.GameServer.ServerConfig;
import botfight.core.Player.PlayerId;
import botfight.core.action.Action;
import botfight.core.action.ActionCollector;

typedef PlayerActions<Ta : Action> = {
	var pid : PlayerId;
	var actions : Array<Ta>;
}

abstract PlayersActions<Ta : Action>(Array<PlayerActions<Ta>>) from Array<PlayerActions<Ta>> to Array<PlayerActions<Ta>> {
	@:op(a()) public function iter(f : (PlayerId, Ta, Int) -> Void) : Void {
		for (pa in this) 
			for (i in 0...pa.actions.length)
				f(pa.pid, pa.actions[i], i);
	}

	/*@:op(a()) public function filter(f : Ta -> Bool) : Array<PlayerActions<Ta>> {
		return this.filterMap(pa -> {
			var as = pa.actions.filter(f);
			return as.empty() ? null : { pid : pa.pid, actions : as };
		});
	}*/
}

@:allow(botfight.core.GameServer)
final class SimulationContext<Ta : Action> {
	public var actions(default, null) : PlayersActions<Ta>;
	public var rnd(default, null) : hxd.Rand;

	var wasAlive : Array<PlayerId>;
	var victories : Array<PlayerId> = [];
	var defeats : Array<PlayerId> = [];

	function new(actions : PlayersActions<Ta>, alive : Array<PlayerId>, seed : Int) {
		this.actions = actions;
		this.rnd = new hxd.Rand(seed);
		this.wasAlive = alive;
	}

	public inline function getAlivePlayers() {
		return wasAlive.filter(isAlive);
	}

	public inline function isAlive(pid : PlayerId) : Bool {
		return wasAlive.has(pid) && !defeats.has(pid);
	}

	public function victory(pid : PlayerId) : Void {
		if (!isAlive(pid) || victories.has(pid)) return;
		victories.push(pid);
	}

	public function defeat(pid : PlayerId) : Void {
		if (!isAlive(pid)) return;
		defeats.push(pid);
		// @todo decide if this should stay here or be handled by the server
		final remain = getAlivePlayers();
		if (remain.length == 1)
			victory(remain[0]);
	}
}

@:allow(botfight.core.GameServer)
abstract class GameSimulation<Ts : GameState, Ta : Action> extends ActionParser<Ta> {

	/**
		Called before the first turn. Should return the initial game state.
		Use [rnd] only to ensure the game will be deterministic with the game seed.
	*/
	abstract function init(players : Array<PlayerId>, rnd : hxd.Rand) : Ts;

	/**
		Called every update. Should mutate state depending on players actions.

		Use [rnd] only to ensure the game will be deterministic with the game seed.

		@todo : should returns logs (errors, warnings, debug) that will be sent back to players
			or out stream passed in parameters
	*/
	abstract function update(state : Ts, ctx : SimulationContext<Ta>) : Void;

	abstract function getTurnActionProfile(state : Ts, pid : PlayerId) : TurnActionProfile<Ta>;

	/**
		Called to decide the winner when the game has reached the final
		turn, or when all players have lost on the same turn.
	*/
	abstract function getTiebreakerScore(state : Ts, pid : PlayerId) : Int;

	/**
		Should generate the information that is sent to the players at the start of the game.
	*/
	abstract function serializeHeaderForPlayer(pid : PlayerId,  initialState : Ts) : Array<String>;
	
	/**
		Should generate the information that is sent each turn to the players, depending
		on the visible state of the game for each of them.
	*/
	abstract function serializeForPlayer(state : Ts, pid : PlayerId) : Array<String>;
}