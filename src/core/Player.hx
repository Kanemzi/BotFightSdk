package core;

import haxe.Timer;
import core.PlayerIO;
import core.Exception;
import core.action.Action;
import core.action.*;

enum Status { 
	Alive;
	Defeated;
	TimedOut;
	Invalid;
	Crashed;
	Terminated;
	Victory;
}

typedef PlayerId = Int;

@:publicFields @:structInit
class PlayerInfo implements hxbit.Serializable {
	var id : PlayerId;
	var name : String;
	var path : String;
}

final class Player<Ta : Action> {
	public inline static final MAX_NAME_LENGTH = 15; 

	public var id(get, never) : PlayerId;
	public var name(get, never) : String;
	public var status(default, null) : Status;
	
	var info : PlayerInfo;
	var io : PlayerIO;

	public function new(info : PlayerInfo , ?io : PlayerIO) {
		this.info = info;
		this.io = io ?? new ProcessPlayerIO(info.path, []);
		status = Alive;
	}

	public function isAlive() return switch (status) {
		case Defeated, TimedOut, Invalid, Crashed, Terminated: false;
		case Alive, Victory: true;
	}

	@:allow(core.GameServer)
	function kill(reason : Status) {
		if (!isAlive()) return;
		status = reason;
		io.dispose();
	}

	function victory() {
		if (!isAlive())
			throw 'Player $name is not alive and can\'t win the game';
		status = Victory;
	}

	public function sendState(state : Array<String>) {
		io.writeString('$state\n');
	}

	public function collectActions<Ts : GameState>(turnProfile : ActionCollector<Ta>, timeout : Float, ap : ActionParser<Ta>) : ActionsResult<Ta> {
		final start = Timer.stamp();
		final deadline = start + timeout;

		function next() {
			while (Timer.stamp() <= deadline) {
				var line = io.poll();
				if (line == null) {
					Sys.sleep(0.001);
					continue;
				}
				var action = ap.parseAction(line);
				if (action == null ) throw new InvalidActionException('Invalid action "$line"');
				return action;
			}
			throw new TimeoutException('Turn timeout reached (${timeout}s)');
		}

		var actions : Array<Ta> = null;
		var error : String = null;
		try {
			actions = turnProfile.collect(next);
		} catch (e : Exception) {
			error = e.message;
			var s = if (io.isDisposed()) Crashed
				else if (Std.isOfType(e, TimeoutException)) TimedOut
				else Invalid;
			kill(s);
		}

		final time = Timer.stamp() - start;
		return {
			pid : id,
			actions : actions,
			time : Std.int(time),
			status : status,
			error : error
		};
	}

	function get_id() return info.id;
	function get_name() return info.name;
}