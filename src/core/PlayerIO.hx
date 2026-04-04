package core;

import haxe.Timer;
import utils.Mutex;
import haxe.io.Input;
import sys.thread.Thread;
import sys.io.Process;
import core.Exception.TimeoutException;

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

	public function new(path : String, args : Array<String>) {
		process = new Process('hl $path ${args.join(" ")}');
		
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
			if (line != null) return line;
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