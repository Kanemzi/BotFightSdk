package botfight;

import botfight.core.Exception;
import botfight.core.Player;
import botfight.core.Player.PlayerInfo;
import botfight.core.PlayerIO;
import botfight.core.action.Action;
import botfight.core.GameState;
import botfight.core.History;

class InvalidMatch extends Exception {}
class InvalidPlayerException extends Exception {}

typedef GameInfo = { seed : Int, players : Array<PlayerInfo> }

@:allow(botfight.core.History)
abstract class Match<Ts : GameState, Ta : Action> implements hxbit.Serializable {
	@:s var teamSize : Int = 1;
	@:s var players : Array<PlayerInfo> = [];
	@:s var games : Array<History<Ts, Ta>> = [];
	@:s var seed : Int;

	var started = false;
	var rnd : hxd.Rand;

	public function new(seed : Int, teamSize = 1) {
		this.seed = seed;
		this.teamSize = teamSize;
	}

	final public function addPlayer(path : String) : PlayerInfo {
		if (started) throw 'Can\'t add player $path after match start';
		
		final pid = players.length;
		var name = null;
		var pio : PlayerIO<Ta> = null;
		try {
			pio = new ProcessPlayerIO<Ta>(path, ["--config"]);
			name = pio.readLine(1.0);
			if (name.length > Player.MAX_NAME_LENGTH || !~/^[\w~]+$/.match(name))
				throw new InvalidPlayerException('$path : Player name should be ${Player.MAX_NAME_LENGTH} max alphanumeric characters');
		} catch (e : InvalidPlayerException) {
			pio?.dispose();
			throw e;
		} catch (_ : TimeoutException) {
			pio?.dispose();
			throw new InvalidPlayerException('Process $path (id=$pid) should send a name when started with parameter --config');
		} catch (e : CrashException) {
			pio?.dispose();
			throw new InvalidPlayerException('Process $path (id=$pid) crashed during initialization : ${e.message}');
		} catch (e : haxe.Exception) {
			pio?.dispose();
			throw new InvalidPlayerException('Could not run $path properly : $e');
		}
		pio?.dispose();

		final info : PlayerInfo = {
			id: pid,
			team : hxd.Math.floor(pid / teamSize),
			path : path,
			name : name
		};
		
		players.push(info);
		return info;
	}

	inline function genSeed() { return rnd?.random(Const.INT_MAX) ?? 0; }

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
	public function new(count : Int, seed : Int, teamSize = 1) {
		super(seed, teamSize);
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