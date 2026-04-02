import sys.thread.Thread;

import Player.ActionsResult;

typedef ServerConfig = {
	var version : String;
	var minPlayers : Int;
	var maxPlayers : Int;
	var maxTurns : Int;
	var firstTurnTimeout : Int;
	var turnTimeout : Int;
	var turnModel : Class<TurnModel>;
}

enum PartyKind {
	Multiple(count : Int);
	BestOf(bo : Int);
	Tournament(bo : Int, playerCount : Int);
}

@:autoBuild(Macros.buildActionParser())
@:access(GameState)
abstract class GameServer<TState : GameState, TAction : EnumValue> {
	var config(default, null) : ServerConfig;
	var players : Array<Player<TAction>>;
	var history : History<TState, TAction>; // @todo save player and server logs per turn

	var state(get, never) : TState;
	function get_state() return cast history.turns[history.turns.length - 1].state;
	
	var turnModel : TurnModel;
	var turn(get, never) : Int;
	function get_turn() return history.turns.length;

	var serializer : hxbit.Serializer;

	abstract function init() : TState; // Initializes the game state
	abstract function update(state : TState, ) : Void; // Updates the state based on last player actions
	abstract function serializeStateForPlayer(player : Player<TAction>) : Array<String>;
	public abstract function parseAction(action : String) : TAction; // @auto generated
	public abstract function getDefaultAction() : TAction; // Will be used for timed-out players 
	abstract function getExpectedActionCount(player : Player<TAction>) : Int; 


	public function new(args : Array<String>, config : ServerConfig) {
		this.config = config;

		// @todo check bot count using config
		players = [];
		serializer = new hxbit.Serializer();
	}

	public function addPlayer(botPath : String) {
		var id = players.length;
		players.push(new Player(id, botPath));
	}

	inline function getAlivePlayers() return players.filter(p -> p.status.get() == Alive);

	public function run() {
		if (players.length < config.minPlayers || players.length > config.maxPlayers)
			throw "Trying to run a game with an invalid amount of players";

		turnModel = Type.createInstance(config.turnModel, []);

		history = new History(config.version, players.map(p -> p.name));
		history.addTurn([], init());

		while (history.length < config.maxTurns + 1) {
			var newState : TState = cast serializer.unserialize(serializer.serialize(state), GameState);

			final playing = turnModel.getPlayingThisTurn(getAlivePlayers(), newState, turn);
			final actions = playing.map(playTurn);

			trace('--- Turn ${history.turns.length} ---');
			trace('Played : ${actions.map(a -> '[${players[a.id]} : ${a.time}ms]').join(" ")}');
			trace('before : $state');

			update(newState);
			trace('after : $state');
			
			history.addTurn(actions, newState);
		}

		var bytes = serializer.serialize(history);
		var hist = serializer.unserialize(bytes, History);
		trace(hist);
	}

	function playTurn(player : Player<TAction>) : ActionsResult<TAction> {
		final c = getExpectedActionCount(player);
		final timeout = turn <= 1 ? config.firstTurnTimeout : config.turnTimeout;
		final state = serializeStateForPlayer(player);
		
		player.sendState(state);
		return player.collectActions(c, timeout / 1000., this);
	}

	public static function actionToString(action : EnumValue) {
		var name = action.getName().toUpperCase();
		var params = Type.enumParameters(action).map(Std.string);
		return [name].concat(params).join(" ");
	}
}