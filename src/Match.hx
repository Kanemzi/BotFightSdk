
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

typedef GameInfo = { seed : Int, players : Array<PlayerInfo> }

abstract class Match<Ts : GameState, Ta : Action> implements hxbit.Serializable {
	@:s var players : Array<PlayerInfo> = [];
	@:s var games : Array<History<Ts, Ta>> = [];
	@:s var seed : Int;

	var started = false;
	var rnd : hxd.Rand;

	public function new(seed : Int) {
		this.seed = seed;
	}

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

	inline function genSeed() { return rnd?.random(1 << 31 - 1) ?? 0; }

	final public function pollGames() : Array<GameInfo> {
		if (!started) {
			started = true;
			rnd = new hxd.Rand(seed);
			init();
		}
		return getNextGameBatch();
	}
	
	final public function onGameComplete(g : History<Ts, Ta>) {
		games.push(g);
	}

	function init() {};
	function getNextGame() : GameInfo { throw 'getNextGame() not implemented for match mode ${Type.getClassName(Type.getClass(this))}'; };
	function getNextGameBatch() : Array<GameInfo> {
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
	public function new(count : Int, seed : Int) {
		super(seed);
		this.count = count;
	}

	override function getNextGameBatch() : Array<GameInfo> {
		return [for (_ in 0...count) {
			seed : genSeed(),
			players : players.copy()
		}];
	}

	function isComplete() return games.length == count;
	function toString() { return 'Series of $count'; }
}