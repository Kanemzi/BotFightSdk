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

@:structInit
final class ActionsResult<TAction : EnumValue> implements hxbit.Serializable {
	var actions : Array<TAction>;
	var error : Null<String>;
	var time : Int;
}

@:access(GameServer)
final class Player<TAction : EnumValue> {
	public var id(default, null) : Int;
	public var name(default, null) : String;
	// public var path(default, null) : String;
	public var history(default, null) : Array<TAction>;
	public var status(default, null) : Mutex<Status>;

	var process : Process;
	var buffer : Mutex<Array<String>>;
	var thread : Thread;

	public function new(id, name, path) {
		this.id = id;
		this.name = name;
		// this.path = path;
		process = new Process('hl $path');
		status = new Mutex(Alive);
		buffer = new Mutex([]);
		thread = Thread.create(processThread);
	}

	public function kill() {
		status.set(Killed);
	}

	function processThread() {
		// var process = new Process('hl $path');
		while (true) {
			var line = process.stdout.readLine();
			if (status.get() != Alive)
				break;
			
			buffer.execute(b -> b.push(line));
		}
	}

	public function getLastAction() : TAction {
		if( history.length == 0 ) return null;
		return history[history.length - 1];
	}

	public function collectActions<TState : GameState>(expected : Int, timeout : Float, gs : GameServer<TState, TAction>) : ActionsResult<TAction> {
		var raw : Array<String> = [];

		var start = Timer.stamp();
		var now = start;

		if (status.get() == Alive) { // When not alive, just fill with default actions
			while (raw.length < expected) {

				var line = null;
				buffer.execute(b -> line = b.shift());
				if (line != null)
					raw.push(line);
	
				now = Timer.stamp();
				if (now - start > timeout) {
					var code = process.exitCode(false); 
					status.set(switch (code) {
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

		return {actions : actions, time : Std.int(time * 1000), error : error};
	}
}