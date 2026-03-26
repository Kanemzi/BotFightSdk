import sys.thread.Thread;

typedef ServerConfig = {
    var version : String;
    var minPlayers : Int;
    var maxPlayers : Int;
}

enum DisqualifyReason {
    Timeout;
    InvalidAction(action : String);
}


enum PlayerStatus {
    None;
    Win;
    Disqualified<DisqualifyReason>;
}

enum PartyKind {
    Multiple(count : Int);
    BestOf(bo : Int);
    Tournament(bo : Int, playerCount : Int);
}

abstract class GameState { }

abstract class GameServer<TAction : EnumValue, TPlayer : Player<TAction>, TState : GameState> {
    
    var players : Array<TPlayer>;
    var state : TState;
    
    abstract public function getConfig() : ServerConfig;
    abstract function init() : TState;
    abstract function update(state : TState) : Void;

    public function new(args : Array<String>) {
        if( args.contains("--config") ) {
            var config = haxe.Json.stringify(getConfig());
            Sys.stdout().writeString('$config\n');
            Sys.stdout().flush();
            return;
        }

        // @todo check bot count using config

        state = init();
    }

    function process() {

    }

}