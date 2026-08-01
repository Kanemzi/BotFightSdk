package cogpit.core;

import haxe.Timer;
import cogpit.utils.Mutex;
import sys.thread.Thread;
import sys.io.Process;
import cogpit.core.Exception;
import cogpit.core.Player.Status;
import cogpit.core.Player.PlayerId;
import cogpit.core.action.Action;
import cogpit.core.action.ActionCollector;
import cogpit.core.action.ActionsResult;

interface PlayerIO<Ta : Action> {
	function readLine(timeout : Float) : String;
	function writeLine(s : String) : Void;
	function collectActions(turnProfile : ActionCollector<Ta>, timeout : Float, ap : ActionParser<Ta>) : ActionsResult<Ta>;
	function dispose() : Void;
	function isDisposed() : Bool;
}

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