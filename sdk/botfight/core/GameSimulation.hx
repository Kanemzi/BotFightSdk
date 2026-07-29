package botfight.core;

import botfight.core.Player.PlayerId;
import botfight.core.Player.TeamId;
import botfight.core.Player.PlayerInfo;
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
	public var turn(default, null) : Int; 
	public var actions(default, null) : PlayersActions<Ta>;
	public var rnd(default, null) : hxd.Rand;
	
	var seed : Int;
	var players : Map<PlayerId, PlayerInfo>;
	var wasAlive : ReadOnlyArray<PlayerId>;
	var victories : Array<PlayerId> = [];
	var defeats : Array<PlayerId> = [];

	function new(players : ReadOnlyArray<PlayerInfo>, seed : Int) {
		this.players = [for (p in players) p.id => p];
		this.seed = seed;
		rnd = new hxd.Rand(seed);
		initTurn(0, players.map(p -> p.id));
	}

	function initTurn(turn : Int, alive : ReadOnlyArray<PlayerId>, ?actions : PlayersActions<Ta>) {
		this.turn = turn;
		this.wasAlive = alive;
		this.actions = actions;
		rnd.init(seed + turn);
		victories.resize(0);
		defeats.resize(0);
	}

	public inline function getAlivePlayers() {
		return wasAlive.filter(isAlive);
	}

	public inline function isAlive(pid : PlayerId) : Bool {
		return wasAlive.has(pid) && !defeats.has(pid);
	}

	public inline function getTeam(pid : PlayerId) : TeamId {
		return players.get(pid).team;
	}

	public inline function getTeammates(pid : PlayerId, alive = true) : Array<PlayerId> {
		final team = getTeam(pid);
		return [for (_ => p in players) if (p.id != pid && getTeam(p.id) == team && (!alive || isAlive(p.id))) p.id];
	}

	public inline function getName(pid : PlayerId) : String {
		return players.get(pid).name;
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

@:forward(getTeam, getTeammates, getName)
abstract InitContext<Ta : Action>(SimulationContext<Ta>) from SimulationContext<Ta> {
	public var rnd(get, never) : hxd.Rand;
	inline function get_rnd() return this.rnd;
	public function getPlayers() return this.getAlivePlayers();
}

@:allow(botfight.core.GameServer)
abstract class GameSimulation<Ts : GameState, Ta : Action> extends ActionParser<Ta> {

	/**
		Called before the first turn. Should return the initial game state.
		Use [ctx.rnd] only to ensure the game will be deterministic with the game seed.
	*/
	abstract function init(ctx : InitContext<Ta>) : Ts;

	/**
		Called every update. Should mutate state depending on players actions.

		Use [ctx.rnd] only to ensure the game will be deterministic with the game seed.

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
	abstract function serializeHeaderForPlayer(initialState : Ts, pid : PlayerId) : Array<String>;
	
	/**
		Should generate the information that is sent each turn to the players, depending
		on the visible state of the game for each of them.
	*/
	abstract function serializeForPlayer(state : Ts, pid : PlayerId) : Array<String>;
}