package cogpit.core;

import haxe.Timer;
import cogpit.core.PlayerIO;
import cogpit.core.Exception;
import cogpit.core.action.Action;
import cogpit.core.action.*;

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
typedef TeamId = Int;

@:publicFields @:structInit
class PlayerInfo implements hxbit.Serializable {
	var id : PlayerId;
	var team : TeamId;
	var name : String;
	var path : String;
}

final class Player<Ta : Action> {
	public inline static final MAX_NAME_LENGTH = 15;
	
	public var info(default, null) : PlayerInfo;
	public var status(default, null) : Status;
	
	public var id(get, never) : PlayerId;
	public var team(get, never) : TeamId;

	var io : PlayerIO<Ta>;

	public function new(info : PlayerInfo, io : PlayerIO<Ta>) {
		this.info = info;
		this.io = io;
		status = Alive;
	}

	public function isAlive() return switch (status) {
		case Alive: true;
		case Defeated, TimedOut, Invalid, Crashed, Terminated, Victory: false;
	}

	@:allow(cogpit.core.GameServer)
	function kill(reason : Status) {
		if (!isAlive()) return;
		status = reason;
		io.dispose();
	}

	@:allow(cogpit.core.GameServer)
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

	inline function get_id() return info.id;
	inline function get_team() return info.team;
}