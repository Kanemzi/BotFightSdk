package botfight.core;

import haxe.Timer;
import botfight.core.PlayerIO;
import botfight.core.Exception;
import botfight.core.action.Action;
import botfight.core.action.*;

enum Status {
	Alive; // Currently active in the game
	Defeated; // Has lost the game
	TimedOut; // Has not responded in time for a turn
	Crashed; // The process has crashed
	Invalid; // An exception occured while collecting actions (unknown cause)
	Terminated; // Was disposed properly at the end of the game
	Victory; // Has won the game
}

typedef PlayerId = Int;

final class Player<Ta : Action> {
	public inline static final MAX_NAME_LENGTH = 15;
	
	public var id(default, null) : PlayerId;
	public var status(default, null) : Status;

	var io : PlayerIO<Ta>;

	public function new(id : PlayerId, io : PlayerIO<Ta>) {
		this.id = id;
		this.io = io;
		status = Alive;
	}

	public function isAlive() return switch (status) {
		case Alive: true;
		case Defeated, TimedOut, Invalid, Crashed, Terminated, Victory: false;
	}

	@:allow(botfight.core.GameServer)
	function kill(reason : Status) {
		if (!isAlive()) return;
		status = reason;
		io.dispose();
	}

	@:allow(botfight.core.GameServer)
	function sendLines(lines : Array<String>) : Bool {
		try {
			for (l in lines) io.writeLine(l);
			return true;
		} catch (e : CrashException) {
			status = Crashed;
			return false;
		} catch (e : std.haxe.Exception) {
			status = Invalid;
			return false;
		}
	}

	public function play(data : Array<String>, turnProfile : ActionCollector<Ta>, timeout : Float, ap : ActionParser<Ta>) : ActionsResult<Ta> {
		final start = Timer.stamp();
		if (!sendLines(data)) return {
			pid : id,
			actions : [],
			time : Timer.stamp() - start,
			status : status,
			error : 'Failed to send turn data',
			logs : [] // @todo collect last logs before or retrieve them in the error field
		};

		var result : ActionsResult<Ta> = io.collectActions(turnProfile, timeout, ap);
		result.pid = id;

		status = result.status;
		return result;
	}
}