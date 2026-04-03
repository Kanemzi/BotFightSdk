package core;

import haxe.Timer;
import core.PlayerIO;
import core.Exception;
import core.action.*;

enum Status { 
	Alive;
	Defeated;
	TimedOut;
    Invalid;
	Crashed;
    Terminated;
}

typedef PlayerId = Int;

@:access(GameServer)
final class Player<Ta : EnumValue> {
	public var id(default, null) : PlayerId;
	public var name(default, null) : String;
	public var status(default, null) : Status;

	var io : PlayerIO;

	public function new(id, ?path : String, ?io : PlayerIO) {
		this.id = id;
		this.io = io ?? new ProcessPlayerIO(path);
		status = Alive;

		try {
			name = this.io.readLine(1000);
		} catch( e : TimeoutException) {
			// @todo catch some sort of generic PlayerProtocolException in GameServer to end the game
			trace('Player $path didn\'t send its name');
		}
	}

    public function isAlive() return switch (status) {
        case Defeated, TimedOut, Invalid, Crashed, Terminated: false;
        case Alive: true;
    }

	public function kill(reason : Status) {
        if (!isAlive()) return;
		status = reason;
		io.dispose();
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
            id : id,
            actions : actions,
            time : Std.int(time * 1000),
            status : status,
            error : error
        };
	}
}