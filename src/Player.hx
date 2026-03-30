import sys.io.Process;
import sys.thread.Thread;
import sys.thread.Mutex;

class Player<TAction : EnumValue> {
	public var id(default, null) : Int;
	public var name(default, null) : String;
	var process : Process;
	var history : Array<TAction>;
	var alive : Bool = true;
 
	var buffer : Array<String> = [];
	var thread : Thread;
	var mut : Mutex;

	public function new(id, name, path) {
		this.id = id;
		this.name = name;
		process = new Process('hl $path');
		mut = new Mutex();
		Thread.create(reader);
	}

	public function kill() {
		mut.acquire();
		alive = false;
		mut.release();
	}

	function reader() {
		while (alive) {
			var line = process.stdout.readLine();
			mut.acquire();
			buffer.push(line);
			mut.release();
		}
	}

	public function getLastAction() : TAction {
		if( history.length == 0 ) return null;
		return history[history.length - 1];
	}

	public function collectActions(count : Int, timeout : Float) : Array<TAction> {
		var result : Array<TAction> = [];
	}
}