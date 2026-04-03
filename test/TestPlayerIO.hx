package;

import Player;

class TestPlayerIO implements PlayerIO {
	var buffer : Array<String> = [];
	var delay : Float ;

	public function new(actions : Array<String>, delay = 0) {
		actions.unshift('BotTest~${Std.random(1000)}');
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