import haxe.io.Input;
import haxe.Timer;
import sys.io.Process;
import sys.thread.Thread;
import utils.Mutex;


enum Status { 
	Alive;
	Killed;
	TimedOut;
	Crashed;
}

typedef PlayerId = Int;

@:structInit @:generic
final class ActionsResult<TAction : EnumValue> implements hxbit.Serializable {
	@:s public var id : PlayerId;
	@:s public var error : Null<String>;
	
	public var actions : Array<TAction>;
	public var time : Int;

	public function customSerialize(ctx : hxbit.Serializer) @:privateAccess {
		ctx.addInt(actions?.length);
		for (a in actions) ctx.addDynamic(a);
	}

	public function customUnserialize(ctx : hxbit.Serializer) @:privateAccess {
		var len = ctx.getInt();
		actions = [for (_ in 0...len) ctx.getDynamic()];
	}
}

@:access(GameServer)
final class Player<TAction : EnumValue> {
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
        case Killed, TimedOut, Crashed: true;
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

	public function collectActions<TState : GameState>(expected : Int, timeout : Float, gs : GameServer<TState, TAction>) : ActionsResult<TAction> {
		var raw : Array<String> = [];

		var start = Timer.stamp();
		var now = start;

		if (status.get() == Alive) { // When not alive, just fill with default actions
			while (raw.length < expected) {

				var line = null;
				buffer.execute(b -> line = b.shift(), false);
				if (line != null)
					raw.push(line);
	
				now = Timer.stamp();
                var elapsed = now - start; 
				if (elapsed > timeout) {
					var code = process.exitCode(false); 
					kill(code == null ? TimedOut : Crashed);
					break;
				}
			}
		}

		var actions = [for (i in 0...expected)
			(i < raw.length ? gs.parseAction(raw[i]) : null) ?? gs.getDefaultAction()
		];
		var time = now - start;
		var error = null;
		if (status.get() != Alive) {
			// @todo error message 
		}

		var res : ActionsResult<TAction> = {id: id, actions : actions, time : Std.int(time * 1000), error : error};
		return res;
	}
}