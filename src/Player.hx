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

	var process : Process;
	var thread : Thread;
	var buffer : Mutex<Array<String>>;

	//var logs : Mutex<Array<String>>;
	var logsThread : Thread;

	public function new(id, path) {
		this.id = id;
		status = new Mutex(Alive);
		buffer = new Mutex([]);
		process = new Process('hl $path');

		this.name = process.stdout.readLine();
		
		thread = Thread.create(processThread);
		//logs = new Mutex([]);
		logsThread = Thread.create(() -> {
			try while (true) {
				var line = process.stderr.readLine();
				trace('[$name] : $line');
				//logs.execute(b -> b.push(line));
			} catch(e : haxe.io.Eof) {}
		});
	}

	function setStatus(s : Status) {
		status.set(s);
		switch (s) {
			case Alive:
			case Killed, TimedOut, Crashed:
				thread?.disposeNative();
				logsThread?.disposeNative();
		}
	}

	public function kill() {
		setStatus(Killed);
	}

	function processThread() {
		try while (true) {
			var line = process.stdout.readLine();
			if (status.get() != Alive)
				break;
			
			buffer.execute(b -> b.push(line));
		} catch(e : haxe.io.Eof) {
			setStatus(Crashed);
		}
	}

	public function sendState(state : Array<String>) {
		for (s in state) process.stdin.writeString('$s\n');
	}

	public function collectActions<TState : GameState>(expected : Int, timeout : Float, gs : GameServer<TState, TAction>) : ActionsResult<TAction> {
		var raw : Array<String> = [];

		var start = Timer.stamp();
		var now = start;
/*
		logs.execute(logs -> {
			while( logs.length > 0 ) {
				trace('[$name] : ${logs.shift()}');
			}
		});*/

		if (status.get() == Alive) { // When not alive, just fill with default actions
			while (raw.length < expected) {

				var line = null;
				buffer.execute(b -> line = b.shift(), false);
				if (line != null)
					raw.push(line);
	
				now = Timer.stamp();
				if (now - start > timeout) {
					var code = process.exitCode(false); 
					setStatus(switch (code) {
						case null: TimedOut;
						default: Crashed;
					});
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