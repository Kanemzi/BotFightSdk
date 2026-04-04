
import core.Exception;
import core.Player;
import core.PlayerIO;
import core.action.Action;
import core.GameState;
import core.History;

class InvalidMatch extends Exception {}
class InvalidPlayer extends Exception {}

class GameSlot implements hxbit.Serializable {

}

typedef GameCandidates = Array<PlayerInfo>;

class Match<Ts : GameState, Ta : Action> implements hxbit.Serializable {
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

	public function toString() { return "Default"; }

	final public function hasNext() : Bool {
		return false;
	}

	final public function getNextGameBatch() : Array<GameCandidates> {
		if (!started) {
			started = true;
			init();
		}

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
	
	final public function onGameComplete(g : History<Ts, Ta>) {
		games.push(g);
	}

	function init() { throw 'Default match class can\'t be started'; }
	function getNextGame() : GameCandidates { return null; }
	function isComplete() : Bool { return true; }
}

class Series<Ts : GameState, Ta : Action> extends Match<Ts, Ta> {
	var count : Int;
	public function new(count : Int) {
		super();
		this.count = count;
	}

	override function toString() { return 'Series of $count'; }

	// @todo implement
}

class BestOf<Ts : GameState, Ta : Action> extends Match<Ts, Ta> {
	var count : Int;
	public function new(count : Int) {
		super();
		this.count = count;
	}

	override function toString() { return 'Best of $count'; }

	// @todo implement
}
