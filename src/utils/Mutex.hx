package utils;

class Mutex<T> {
	@:noPrivateAccess var val : T;
	@:noPrivateAccess var mut : sys.thread.Mutex;

	public function new(v : T) {
		mut = new sys.thread.Mutex();
		set(v);
	}

	function acquire(block : Bool) {
		if (block) {
			mut.acquire();
			return true;
		} else
			return !mut.tryAcquire();
	}

	public function get(block = true) : T {
		if (!acquire(block)) return null;
		var v = val;
		mut.release();
		return v;
	}

	public function set(v : T, block = true) : Bool {
		if (!acquire(block)) return false;
		val = v;
		mut.release();
		return true;
	}

	public function execute(f : T -> Void, block = true) {
		if (!acquire(block)) return;
		f(val);
		mut.release();
	}
}