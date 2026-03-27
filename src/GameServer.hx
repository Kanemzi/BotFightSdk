import sys.thread.Thread;
import macros.GameServerMacros;

typedef ServerConfig = {
	var version : String;
	var minPlayers : Int;
	var maxPlayers : Int;
}

enum DisqualifyReason {
	Timeout;
	InvalidAction(action : String);
}

/*
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

interface PlayerState {}
abstract class GameState {
	var playerState : Array<PlayerState>;

	@:generic public function getPlayerState<T : EnumValue>(p : Player<T>) {
		if (p.id >= playerState.length)
			throw 'No state for player [id=${p.id}]';
		return playerState[p.id];
	}
}

abstract class GameServer<TState : GameState, TAction : EnumValue> {
	var players : Array<Player<TAction>>;
	var state : TState;
	
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

		state = init();
	}

	function run() {

	}

}