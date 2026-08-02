package cogpit.core;

import cogpit.Match.InvalidPlayerException;
import cogpit.core.Exception;
import cogpit.core.Player.PlayerId;
import cogpit.core.Player.Status;
import cogpit.core.action.Action;
import cogpit.core.action.ActionCollector;
import cogpit.core.action.ActionsResult;
import cogpit.utils.Mutex;
import haxe.Timer;
import sys.io.Process;
import sys.thread.Thread;

interface PlayerIO<Ta : Action> {
	function readLine(timeout : Float) : String;
	function writeLine(s : String) : Void;
	function collectActions(turnProfile : ActionCollector<Ta>, timeout : Float, ap : ActionParser<Ta>) : ActionsResult<Ta>;
	function dispose() : Void;
	function isDisposed() : Bool;
}

interface PlayerIOProvider {
	function matches(path : String) : Bool;
	function resolveName(path : String) : String;
	function create<Ta : Action>(path : String) : PlayerIO<Ta>;
}

/**
	Allows retrieving bot names and creating their PlayerIO based on a path
*/
class PlayerIOResolver {
	static var providers : Array<PlayerIOProvider>;
	public static function register(p : PlayerIOProvider) (providers ??= []).push(p);

	// Tries to find a suitable PlayerIO based on a path
	static inline function find(path : String) : PlayerIOProvider {
		final p = providers.find(p -> p.matches(path));
		if (p == null)
			throw 'Could not find any suitable PlayerIO for path $path';
		return p;
	}

	public static function resolveName(path : String) return find(path).resolveName(path);
	public static function create<Ta : Action>(path : String) return find(path).create(path);
}

/**
	Retrieve bot actions from processes that receive the game state every turn
*/
class ProcessPlayerIO<Ta : Action> implements PlayerIO<Ta> {
	var buffer : Mutex<Array<String>>;
	var logs : Mutex<Array<String>>;
	var eof : Mutex<Bool>;
	var process : Mutex<Process>;

	var thread : Thread;
	var logger : Thread;

	public function new(path : String, args : Array<String>) {
		final p = new Process('hl', [path].concat(args));
		process = new Mutex(p);

		buffer = new Mutex([]);
		logs = new Mutex([]);
		eof = new Mutex(false);

		thread = Thread.create(reader.bind(p.stdout, buffer, null));
		thread.name = '${path}_data';
		logger = Thread.create(reader.bind(p.stderr, logs, Sys.stderr()));
		logger.name = '${path}_log';
	}

	function reader(i : haxe.io.Input, o : Mutex<Array<String>>, ?forward : haxe.io.Output) {
		try while (true) {
			final line = i.safeReadLine();
			forward?.writeString('[forward] $line\n');
			o.execute(o -> o.push(line));
		} catch (e : haxe.io.Eof) {
			eof.set(true);
		} catch (_) {}
	}

	function poll() : Null<String> return buffer.map(b -> b.shift(), false);

	function collectLogs() : Array<String> {
		var l = null;
		var r = [];
		while ((l = logs.map(b -> b.shift(), false)) != null) r.push(l);
		return r;
	}

	function makeCrashException() : CrashException {
		final code = process.map(p -> p?.exitCode(false), false);
		final l = buffer.map(b -> b.copy(), false) ?? [];
		var msg = 'Player process crashed (exit=$code)';
		if (!l.empty()) msg += ' | Logs :\n${l.join("\n")}';
		return new CrashException(msg);
	}

	public function readLine(timeout : Float) : String {
		final deadline = Timer.stamp() + timeout;
		while (Timer.stamp() <= deadline) {
			final line = poll();
			if (line != null) return line;
			if (eof.get(false)) throw makeCrashException();
			Sys.sleep(0.001);
		}
		throw new TimeoutException('Timeout reached (${timeout}s)');
	}

	public function writeLine(s : String) {
		final ok = process.map(p -> {
			if (p == null) return false;
			try { p.stdin.writeString('$s\n'); return true; }
			catch (_) return false;
		});
		if (!ok) throw makeCrashException(); // called after releasing the process lock
	}

	public function collectActions(turnProfile : ActionCollector<Ta>, timeout : Float, ap : ActionParser<Ta>) : ActionsResult<Ta> {
		final start = Timer.stamp();
		final deadline = start + timeout;

		function next() : Ta {
			final line = readLine(deadline - Timer.stamp());
			return ap.parseAction(line)
				?? throw new InvalidActionException('Invalid action "$line"');
		}

		var actions : Array<Ta> = null;
		var error : String = null;
		var status : Status;
		try {
			actions = turnProfile.collect(next);
			status = Alive;
		} catch (e : TimeoutException) {
			error = e.message; status = TimedOut;
		} catch (e : CrashException) {
			error = e.message; status = Crashed;
		} catch (e : InvalidActionException) {
			error = e.message; status = Invalid;
		} catch (e : std.haxe.Exception) {
			// @todo Exception might not be core.Exception. Therefore it might not be bot's fault
			error = e.message; status = Invalid;
		}

		return {
			pid : -1,
			actions : actions ?? [],
			time : Timer.stamp() - start,
			status : status,
			error : error,
			logs : collectLogs(),
		};
	}

	public function dispose() {
		process.execute(p -> {
			if (p == null) return;
			p.stderr.close();
			p.stdin.close();
			p.stdout.close();
			p.kill();
			p.close();
		});
		process.set(null);
	}

	public function isDisposed() {
		return process.map(p -> p == null || p.exitCode(false) != null) ?? true;
	}
}

class ProcessPlayerIOProvider implements PlayerIOProvider {	
	public function new() {}

	public function matches(path : String) : Bool return true; // will try to run anything as a fallback

	public function resolveName(path : String) : String {
		var pio : ProcessPlayerIO<Action> = null;
		try {
			pio = new ProcessPlayerIO(path, ["--config"]);
			final name = pio.readLine(1.0);
			pio.dispose();
			return name;
		} catch (_ : TimeoutException) {
			pio?.dispose();
			throw new InvalidPlayerException('Process $path should send a name when started with parameter --config');
		} catch (e : CrashException) {
			pio?.dispose();
			throw new InvalidPlayerException('Process $path crashed during initialization : ${e.message}');
		} catch (e : haxe.Exception) {
			pio?.dispose();
			throw new InvalidPlayerException('Could not run $path properly : $e');
		}
	}

	public function create<Ta : Action>(path : String) : PlayerIO<Ta> {
		return new ProcessPlayerIO(path, []);
	}
}

/**
	Will send bot actions blindly from a list in a file

	.act format : turn id line, followed by actions (one per line)
	0
	ACTION Param1 Param2
	ACTION2 Param1 Param2 Param3
	1
	ACTION Param1
	3
	...
*/
class ScriptedPlayerIO<Ta : Action> implements PlayerIO<Ta> {
	var turns : Map<Int, Array<String>>;
	var turn = 0;
	var disposed = false;

	public function new(path : String) {
		// Parse actions from file
		turns = new Map();
		var acts = [];
		for (l in sys.io.File.getContent(path).split("\n")) {
			final l = l.trim();
			if (l.length == 0) continue;

			final n = Std.parseInt(l);
			if (n != null && l == '$n') {
				acts = []; // new turn
				turns.set(n, acts);
			} else {
				acts?.push(l);
			}
		}
	}

	public function readLine(timeout : Float) : String {
		throw 'ScriptedPlayerIO does not support readLine()';
	}

	public function writeLine(s : String) {}

	public function collectActions(turnProfile : ActionCollector<Ta>, timeout : Float, ap : ActionParser<Ta>) : ActionsResult<Ta> {
		final start = haxe.Timer.stamp();
		final lines = (turns.get(turn) ?? []).copy();

		function next() : Ta {
			final line = lines.shift();
			if (line == null) throw new InvalidActionException('ScriptedPlayerIO ran out of scripted actions for turn $turn');
			return ap.parseAction(line) ?? throw new InvalidActionException('Invalid scripted action "$line" for turn $turn');
		}

		var actions : Array<Ta> = null;
		var error : String = null;
		var status : Status = Alive;
		try {
			actions = turnProfile.collect(next);
		} catch (e) {
			error = e.message;
			status = Invalid;
		}

		turn++;

		return {
			pid : -1,
			actions : actions ?? [],
			time : Timer.stamp() - start,
			status : status,
			error : error,
			logs : [],
		};
	}

	public function dispose() disposed = true;
	public function isDisposed() return disposed;
}

class ScriptedPlayerIOProvider implements PlayerIOProvider {
	public function new() {}
	public static inline final EXT = "act";
	public function matches(path : String) : Bool return new haxe.io.Path(path).ext == EXT; // @todo read and validate file format
	public function resolveName(path : String) : String return new haxe.io.Path(path).file;
	public function create<Ta : Action>(path : String) : PlayerIO<Ta> return new ScriptedPlayerIO(path);
}