package cogpit;

import cogpit.core.Exception;
import cogpit.core.GameServer;
import cogpit.core.GameState;
import cogpit.core.History;
import cogpit.core.Player.PlayerInfo;
import cogpit.core.Player;
import cogpit.core.PlayerIO.PlayerIOResolver;
import cogpit.core.PlayerIO;
import cogpit.core.action.Action;
import cogpit.live.LiveChannel;
import sys.thread.Mutex;

class InvalidPlayerException extends Exception {}

enum GameStatus { Empty; Ready; Running; Complete; Failed; }

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

	@:allow(cogpit.Match)
	function new(id : Int, name : String, seed : Int) {
		this.name = name;
		this.seed = new hxd.Rand(seed + id).random(Const.INT_MAX);
	}

	@:allow(cogpit.Match)
	function fillPlayers(players : ReadOnlyArray<PlayerInfo>) {
		if (!status.match(Empty)) throw 'Game [$name] already $status, cannot set players';
		this.players = players.copy();
	}

	@:allow(cogpit.Match)
	function registerHistory(history : History<Ts, Ta>) {
		if (status.match(Running)) throw 'Game [$name] already $status, cannot register another history';
		this.history = history;
	}
}

// @todo live mode
// - [ ] still save a file when the match is complete
// - [ ] can't optimize Deterministic because of rollbacks, delta used instead, only the file is optimized

@:allow(cogpit.core.History)
abstract class Match<Ts : GameState, Ta : Action> implements hxbit.Serializable {
	@:s var teamSize : Int;
	@:s var players : Array<PlayerInfo> = [];
	@:s var games : Array<GameSlot<Ts, Ta>> = [];

	@:s var seed : Int;

	var started = false;
	var live : Null<LiveChannel>;
	var liveMut = new Mutex();

	public function new(seed : Int, teamSize = 1) {
		this.seed = seed;
		this.teamSize = teamSize;
	}

	final public function addPlayer(path : String) : PlayerInfo {
		if (started) throw 'Can\'t add player $path after match start';
		
		final pid = players.length;
		final name = PlayerIOResolver.resolveName(path);
		if (name.length > Player.MAX_NAME_LENGTH || !~/^[\w~]+$/.match(name))
			throw new InvalidPlayerException('$path : Player name should be ${Player.MAX_NAME_LENGTH} max alphanumeric characters');

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
		liveMut.acquire();
		games.push(slot);
		liveMut.release();
		live?.notify(MatchSlotAllocated);
		return slot;
	}

	final public function fillSlotPlayers(slot : GameSlot<Ts, Ta>, players : ReadOnlyArray<PlayerInfo>) {
		slot.fillPlayers(players);
		live?.notify(MatchSlotReady);
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
		slot.registerHistory(history);
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
			fillSlotPlayers(slot, players);
		}
	}
	
	function toString() { return 'Series of $count'; }
}