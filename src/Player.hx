import haxe.io.Input;
import haxe.Timer;
import sys.io.Process;
import sys.thread.Thread;
import utils.Mutex;

import ActionCollector;

enum Status { 
	Alive;
	Killed;
	TimedOut;
	Crashed;
    Invalid;
}

abstract class TurnException extends std.haxe.Exception {}
class TimeoutException extends TurnException {}
class InvalidActionException extends TurnException {}

@:structInit @:publicFields
final class ActionsResult<Ta : EnumValue> implements hxbit.Serializable {
	@:s var id : PlayerId;
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

typedef PlayerId = Int;

@:access(GameServer)
final class Player<Ta : EnumValue> {
	public var id(default, null) : PlayerId;
	public var name(default, null) : String;
	public var status(default, null) : Mutex<Status>;

	var buffer : Mutex<Array<String>>;
	var process : Process;
	var thread : Thread;
	var logger : Thread;

	public function new(id, path) {
		this.id = id;
		status = new Mutex(Alive);
		buffer = new Mutex([]);
		process = new Process('hl $path');

        // @todo : setup a timeout here
		name = process.stdout.readLine();

		thread = Thread.create(processInputs);
        logger = Thread.create(() -> {
			try while (process != null) {
				var line = process.stderr.readLine();
				trace('[$name] : $line');
			} catch (_) {}
		});
	}

    public function isKilled() return switch (status.get()) {
        case Killed, TimedOut, Crashed, Invalid: true;
        case Alive : false;
    }

	public function kill(reason = Killed) {
        if( isKilled() ) return;
		status.set(reason);
        process.kill();
        process.close();
        process = null;
	}

	function processInputs() {
		try while (process != null) {
			var line = process.stdout.readLine();
			if (status.get() != Alive)
				break;

			buffer.execute(b -> b.push(line));
		} catch (_) {
			kill(Crashed);
		}
	}

	public function sendState(state : Array<String>) {
		for (s in state) process.stdin.writeString('$s\n');
	}

	public function collectActions<Ts : GameState>(turnProfile : ActionCollector<Ta>, timeout : Float, gs : GameServer<Ts, Ta>) : ActionsResult<Ta> {
		final start = Timer.stamp();
        final deadline = start + timeout;

        function next() {
            while (Timer.stamp() <= deadline) {
                var line = buffer.get(false)?.shift();
                var action = gs.parseAction(line);
                if (action == null ) throw new InvalidActionException('Invalid action "$line"');
                if (action != null) return action;
                Sys.sleep(0.001);
            }
            throw new TimeoutException('Turn timeout reached (${timeout}s)');
        }

        var actions : Array<Ta> = null;
        var error : String = null;
        try {
            actions = turnProfile.collect(next);
        } catch (e : TurnException) {
            error = e.message;
            var s = if (process.exitCode(false) != null) Crashed
                else if (Std.isOfType(e, TimeoutException)) TimedOut
                else Invalid;
            kill(s);
        }

        final time = Timer.stamp() - start;
		return {id : id, actions : actions, time : Std.int(time * 1000), error : error};
	}
}