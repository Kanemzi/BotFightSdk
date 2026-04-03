import GameServer.ActionParser;
import haxe.io.Input;
import haxe.Timer;
import sys.io.Process;
import sys.thread.Thread;
import utils.Mutex;

import ActionCollector;

enum Status { 
	Alive;
	Defeated;
	TimedOut;
    Invalid;
	Crashed;
    Terminated;
}

abstract class PlayerException extends std.haxe.Exception {}
class TimeoutException extends PlayerException {}
class InvalidActionException extends PlayerException {}

@:structInit @:publicFields
final class ActionsResult<Ta : EnumValue> implements hxbit.Serializable {
	@:s var id : PlayerId;
    @:s var status : Status;
	@:s var error : Null<String>;
	
	var actions : Array<Ta>;
	var time : Int;

	public function customSerialize(ctx : hxbit.Serializer) @:privateAccess {
		ctx.addInt(actions?.length);
		for (a in actions) ctx.addDynamic(a);
	}

	public function customUnserialize(ctx : hxbit.Serializer) @:privateAccess {
		var len = ctx.getInt();
		actions = [for (_ in 0...len) ctx.getDynamic()];
	}
}

enum InputKind { Data; Logs; }
interface PlayerIO {
	function poll(t : InputKind = Data) : Null<String>;
	function readLine(timeout : Float) : String;
	function writeString(s : String) : Void;
	function dispose() : Void;
	function isDisposed() : Bool;
}

class ProcessPlayerIO implements PlayerIO {
	var buffer : Mutex<Array<String>>;
	var logs : Mutex<Array<String>>;
	
	var process : Process;
	var thread : Thread;
	var logger : Thread;

	public function new(path : String) {
		process = new Process('hl $path');
		
		buffer = new Mutex([]);
		logs = new Mutex([]);

		thread = Thread.create(reader.bind(process.stdout, buffer));
        logger = Thread.create(reader.bind(process.stderr, logs));
	}

	function reader(i : haxe.io.Input, o : Mutex<Array<String>>) {
		try while (process != null) {
            final line = i.readLine();
			o.execute(o -> o.push(line));
		} catch (_) { } // @todo raise something to the player
	}

	public function poll(t : InputKind = Data) : Null<String> {
		return (t == Logs ? logs : buffer).map(b -> b.shift(), false);
	}

	public function readLine(timeout : Float) : String {
		final start = Timer.stamp();
        final deadline = start + timeout;
		while (Timer.stamp() <= deadline) {
			final line = poll();
			if( line != null) return line;
			Sys.sleep(0.001);
		}
		throw new TimeoutException('Timeout reached (${timeout}s)');
	}

	public function writeString(s : String) {
		process?.stdin.writeString('$s\n');
	}

	public function dispose() {
		process.kill();
        process.close();
        process = null;
	}

	public function isDisposed() return process == null || process.exitCode(false) != null;
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
        if( !isAlive() ) return;
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
        } catch (e : PlayerException) {
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