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
	
//	@:s @:noPrivateAccess var _actions : Array<EnumValue>;
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

	public function new(id, name, path) {
		this.id = id;
		this.name = name;
		status = new Mutex(Alive);
		buffer = new Mutex([]);
		process = new Process('hl $path');
		//thread = Thread.create(processThread);
	}

	public function kill() {
		status.set(Killed);
	}

	function processThread() {
		while (true) {
			var line = process.stdout.readLine();
			if (status.get() != Alive)
				break;
			
			buffer.execute(b -> b.push(line));
		}
	}

	public function sendState(state : Array<String>) {
		//for (s in state) process.stdin.writeString('$s\n');
	}

	public function collectActions<TState : GameState>(expected : Int, timeout : Float, gs : GameServer<TState, TAction>) : ActionsResult<TAction> {
		var raw : Array<String> = [];

		var res : ActionsResult<TAction> = {id: id, actions : [for( _ in 0...expected) gs.getDefaultAction()], time : Std.int(2 * 1000), error : null};
		return res;

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

		var res : ActionsResult<TAction> = {id: id, actions : actions, time : Std.int(time * 1000), error : error};
		return res;
	}
}