package utils;

class Mutex<T> {
	@:noPrivateAccess var val : T;
	@:noPrivateAccess var mut : sys.thread.Mutex;

	inline public function new(v : T) {
		mut = new sys.thread.Mutex();
		set(v);
	}

	inline function acquire(block : Bool) {
		if (block) mut.acquire();
		return block || mut.tryAcquire();
	}

	public inline function set(v : T, block = true) : Bool {
		var ok = acquire(block); 
        if (ok) {
            val = v;
		    mut.release();
        }
        return ok; 
	}

	public inline function execute(f : T -> Void, block = true) {
		if (acquire(block)) {
            try {
                f(val);
                mut.release();
            } catch (e) {
                mut.release();
                throw e;
            }
        }
	}

    public inline function map<U>(f : T -> U, block = true) : Null<U> {
        var res = null;
        if (acquire(block)) {
            try {
                res = f(val);
                mut.release();
            } catch (e) {
                mut.release();
                throw e;
            }
        }
        return res;
    }
}