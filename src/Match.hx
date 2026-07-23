
import core.Exception;
import core.Player;
import core.PlayerIO;
import core.action.Action;
import core.GameServer;
import core.GameState;
import core.History;

class InvalidMatch extends Exception {}
class InvalidPlayer extends Exception {}

class GameSlot implements hxbit.Serializable {

}

typedef GameCandidates = Array<PlayerInfo>;

abstract class Match<Ts : GameState, Ta : Action> implements hxbit.Serializable {
	@:s var players : Array<PlayerInfo> = [];
	@:s var games : Array<History<Ts, Ta>> = [];

	var started = false;

	public function new() {}

	final public function addPlayer(path : String) : PlayerInfo {
		if (started) throw 'Can\'t add player $path after match start';
		
		var name = null;
		var pio : PlayerIO = null;
		try {
			pio = new ProcessPlayerIO(path, ["--config"]);
			name = pio.readLine(1.0);
			pio.dispose();
			if (name.length > Player.MAX_NAME_LENGTH || !~/^[\w~]+$/.match(name))
				throw new InvalidPlayer('$path : Player name should be ${Player.MAX_NAME_LENGTH} max alphanumeric characters');
		} catch (_ : TimeoutException) {
			pio?.dispose();
			throw new InvalidPlayer('Process $path should send a name when started with parameter --config');
		} catch (e : haxe.Exception) {
			throw new InvalidPlayer('Could not run $path properly : $e');
		}

		final info : PlayerInfo = {
			id: players.length,
			path : path,
			name : name
		};

		players.push(info);
		return info;
	}

	final public function pollGames() : Array<GameCandidates> {
		if (!started) {
			started = true;
			init();
		}
		return getNextGameBatch();
	}
	
	final public function onGameComplete(g : History<Ts, Ta>) {
		games.push(g);
	}

	function init() {};
	function getNextGame() : GameCandidates { throw 'getNextGame() not implemented for match mode ${Type.getClassName(Type.getClass(this))}'; };
	function getNextGameBatch() : Array<GameCandidates> {
		// Try to batch the maximum amount of games to play them simultaneously
		// Some formats will need to wait the preview games results before providing more games to play
		var batch = [];
		while (true) {
			var n = getNextGame();
			if (n == null) break;
			batch.push(n);
		}
		return batch;
	}

	abstract function isComplete() : Bool;
	abstract function toString() : String;
}

class Series<Ts : GameState, Ta : Action> extends Match<Ts, Ta> {
	var count : Int;
	public function new(count : Int) {
		super();
		this.count = count;
	}

	override function getNextGameBatch() : Array<GameCandidates> {
		return [for (_ in 0...count) players.copy() ];
	}

	function isComplete() return games.length == count;
	function toString() { return 'Series of $count'; }
}

class BestOf<Ts : GameState, Ta : Action> extends Match<Ts, Ta> {
	var count : Int;
	public function new(count : Int) {
		super();
		this.count = count;
	}

	override function getNextGame() return null;
	function isComplete() return true;
	function toString() { return 'Best of $count'; }
	// @todo implement
}
