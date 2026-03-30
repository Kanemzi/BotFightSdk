import sys.thread.Thread;

typedef ServerConfig = {
	var minPlayers : Int;
	var maxPlayers : Int;
	var firstTurnTimeout : Int;
	var turnTimeout : Int;
	var turnModel : Class<TurnModel>;
}
/*
enum DisqualifyReason {
	Timeout;
	InvalidAction(action : String);
}


enum PlayerStatus {
	None;
	Win;
	Disqualified<DisqualifyReason>;
}*/

enum PartyKind {
	Multiple(count : Int);
	BestOf(bo : Int);
	Tournament(bo : Int, playerCount : Int);
}

abstract class GameState implements hxbit.Serializable {
	abstract function serializeForPlayer<TAction :EnumValue>(player : Player<TAction>) : String;
}

@:autoBuild(Macros.buildActionParser())
@:access(GameState)
abstract class GameServer<TState : GameState, TAction : EnumValue> {
	var config : ServerConfig;
	var players : Array<Player<TAction>>;
	var history : Array<TState>;

    var state(get, never) : TState;
    function get_state() return history[history.length - 1];
    
	var turnModel : TurnModel;
	var turn(get, never) : Int;
	function get_turn() return history.length;

    var serializer : hxbit.Serializer;

	abstract function init() : TState; // Initializes the game state
	abstract function update(state : TState) : Void; // Updates the state based on last player actions
	abstract function parseAction(action : String ) : TAction; // @auto generated
    abstract function getDefaultAction() : TAction; // Will be used for timed-out players 
    abstract function getExpectedActionCount(player : Player) : Int; 

	public function new(args : Array<String>, config : ServerConfig) {
		this.config = config;

		// @todo check bot count using config
        players = [];
        history = [];
        serializer = new hxbit.Serializer();
	}

    public function addPlayer(botPath : String) {
        var id = players.length;
        players.push(new Player(id, botPath.split(".")[0], botPath));
    }

	public function run() {
		if (players.length < config.minPlayers || players.length > config.maxPlayers)
			throw "Trying to run a game with an invalid amount of players";

		turnModel = Type.createInstance(config.turnModel, []);

        history.push(init());
        while( history.length < 3 ) {
            var copy : TState = cast serializer.unserialize(serializer.serialize(state), GameState);
            
			// collect player actions
			var playing = turnModel.getPlayingThisTurn(players, state, turn);

			sendStates(playing);
			var actions = collectActions(playing);

			trace('--- Turn ${history.length} ---');
            trace('before : $state');
            update(state);
            trace('after : $state');
			
			history.push(copy);
        }
	}

	function sendStates(players : Array<Player<TAction>>) {
		for (p in players) {
			var s = state.serializeForPlayer(p);
			// @todo send string to player
		}
	}

	function collectActions(players : Array<Player<TAction>>) : Array<TAction> {
		for (p in players) {
			// retrieve actions from player with timeout
            var c = getExpectedActionCount(p);
            var to = turn <= 1 ? config.firstTurnTimeout : config.turnTimeout;
            p.collectActions(c, to);
		}
		return [];
	}

}