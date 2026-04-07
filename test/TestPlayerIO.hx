package;

import core.Player;
import core.PlayerIO;

class TestPlayerIO implements PlayerIO {
	var buffer : Array<String> = [];
	var delay : Float;

	public function new(actions : Array<String>, args : Array<String> = null, delay = 0) {
		if (args?.indexOf("--config") > 0) {
            buffer = ['BotTest~${Std.random(1000)}'];
            return;
        }
		buffer = actions;
	}

	public function poll(t : InputKind = Data) : Null<String> {
		return t == Logs ? null : buffer.shift();
	}
	public function readLine(timeout : Float) {
		var line = poll();
		if (line != null) {
//			Sys.sleep(delay);
			return line;
		}
		throw new TimeoutException('No more actions available in buffer');
	}

	public function writeString(s : String) {}
	public function dispose() buffer = [];
	public function isDisposed() return buffer.length == 0; 
}