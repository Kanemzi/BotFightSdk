import sys.thread.Thread;

typedef ServerConfig = {
	var version : Int;
	var minPlayers : Int;
	var maxPlayers : Int;
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

abstract class GameState implements hxbit.Serializable {}

@:autoBuild(Macros.buildActionParser())
abstract class GameServer<TState : GameState, TAction : EnumValue> {
	var players : Array<Player<TAction>>;
	var history : Array<TState>;

    var state(get, never) : TState;
    function get_state() return history[history.length - 1];
    
    var serializer : hxbit.Serializer;

	abstract public function getConfig() : ServerConfig;
	abstract function init() : TState;
	abstract function turn(state : TState) : Void;
	abstract function parseAction(action : String ) : TAction;

	public function new(args : Array<String>) {
		if( args.contains("--config") ) {
			var config = haxe.Json.stringify(getConfig());
			Sys.stdout().writeString('$config\n');
			Sys.stdout().flush();
			return;
		}

		// @todo check bot count using config
        players = [];
        history = [];
        serializer = new hxbit.Serializer();
	}

    public function addPlayer(botPath : String) {
        var id = players.length;
        players.push(new Player(id, botPath));
    }

	public function run() {
        history.push(init());

        while( history.length < 3 ) {
            var copy : TState = cast serializer.unserialize(serializer.serialize(state), GameState);
            history.push(copy);
            trace('--- Turn ${history.length} ---');
            trace('before : $state');
            turn(state);
            trace('after : $state');
        }
	}

}