package botfight;

import sys.thread.Mutex;

import botfight.core.Exception;
import botfight.core.Player;
import botfight.core.Player.PlayerInfo;
import botfight.core.PlayerIO;
import botfight.core.action.Action;
import botfight.core.GameServer;
import botfight.core.GameState;
import botfight.core.History;
import botfight.live.LiveChannel;

class InvalidMatch extends Exception {}
class InvalidPlayerException extends Exception {}

enum GameStatus { Empty; Ready; Running; Complete; Failed; }

@:allow(botfight.Match)
class GameSlot<Ts : GameState, Ta : Action> implements hxbit.Serializable {
	@:s public var name(default, null) : String; // Display name for preview
	@:s public var history(default, null) : History<Ts, Ta>;
	
	public var seed(default, null) : Int;
	public var players(default, null) : ReadOnlyArray<PlayerInfo>; 

	public var status(get, never) : GameStatus;
	function get_status() {
		return if (history == null) players == null ? Empty : Ready;
			else if (!history.complete) Running;
			else Complete;
	}

	function new(id : Int, name : String, seed : Int) {
		this.name = name;
		this.seed = new hxd.Rand(seed + id).random(Const.INT_MAX);
	}

	function fillPlayers(players : ReadOnlyArray<PlayerInfo>) {
		if (!status.match(Empty)) throw 'Game [$name] already $status, cannot set players';
		this.players = players.copy();
	}
}

// @todo live mode
// - [ ] still save a file when the match is complete
// - [ ] can't optimize Deterministic because of rollbacks, delta used instead, only the file is optimized

@:allow(botfight.core.History)
abstract class Match<Ts : GameState, Ta : Action> implements hxbit.Serializable {
	@:s var teamSize : Int;
	@:s var players : Array<PlayerInfo> = [];
	@:s var games : Array<GameSlot<Ts, Ta>> = [];

	@:s var seed : Int;

	var started = false;
	var live : Null<LiveChannel>;
	var mut : Mutex = new Mutex();

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

	final public function allocateSlot(name : String) : GameSlot<Ts, Ta> {
		final slot = new GameSlot(games.length, name, seed);
		mut.acquire();
		games.push(slot);
		mut.release();
		live?.notify(MatchSlotAllocated);
		return slot;
	}

	final public function pollGames() : Array<GameSlot<Ts, Ta>> {
		if (!started) {
			started = true;
			init();
		}
		return games.filter(g -> g.status.match(Ready));
	}

	public inline function watch(live : LiveChannel) this.live = live;
	public inline function isComplete() : Bool {
		return started && !games.exists(g -> g.status.match(Empty|Ready));
	}


	final public function run(gsFactory : GameSlot<Ts, Ta> -> GameServer<Ts, Ta>) {
		while (!isComplete()) {
			for (g in pollGames()) {
				var gs = gsFactory(g);
				gs.run(onGameBegin.bind(g), live);
			}
		}
	}

	final function onGameBegin(slot : GameSlot<Ts, Ta>, history : History<Ts, Ta>) {
		slot.history = history;
	}

	/**
		Called on each game complete. Should be used to allocate more GameSlots, or fill players in existing game slots.
	*/
	function onGameComplete(slot : GameSlot<Ts, Ta>) {}

	/**
		Should be used to allocate the initial GameSlot batch.
	*/
	abstract function init() : Void;

	abstract function toString() : String;
}

class Series<Ts : GameState, Ta : Action> extends Match<Ts, Ta> {
	var count : Int;
	public function new(count : Int, seed : Int, teamSize = 1) {
		super(seed, teamSize);
		this.count = count;
	}

	function init() {
		for (i in 0...count) {
			final slot = allocateSlot('Game #$i');
			slot.fillPlayers(players.copy());
		}
	}
	
	function toString() { return 'Series of $count'; }
}