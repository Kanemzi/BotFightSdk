package botfight.utils;

#if !macro

import hl.Gc;
import haxe.io.BytesBuffer;
import haxe.io.Eof;

class Extensions {

	/**
		Thread safe blocking readline function.
		Based on the implementation from haxe.io.Input.readLine().

		Read a line of text separated by CR and/or LF bytes.
		The CR/LF characters are not included in the resulting string.
	*/
	public static function safeReadLine(input : haxe.io.Input) : String {
		var buf = new BytesBuffer();
		var last : Int;
		var s : String;
		try {
			while (true) {
				Gc.blocking(true);
				last = input.readByte();
				Gc.blocking(false);

				if (last == 10) break;
				buf.addByte(last);
			}
			s = buf.getBytes().toString();
			if (s.charCodeAt(s.length - 1) == 13)
				s = s.substr(0, -1);
		} catch (e : Eof) {
			s = buf.getBytes().toString();
			if (s.length == 0)
				throw e;
		}
		return s;
	}

	public static inline function filterMap<T, U>(array : Array<T>, func : T -> U) : Array<U> {
		var res = array.map(func);
		res.keep(e -> e != null);
		return res;
	}
	
	public static inline function castArray<T : {}, S : T>(array : Array<T>, cl : Class<S>) : Array<S> {
		var c : Array<S> = array.filterMap(Std.downcast.bind(_, cl));
		return c.length == array.length ? c : null;
	}

	// @todo remove after LazyIterators integration
	public static inline function keep<T>(array : Array<T>, f : T -> Bool) {
		var i = array.length;
		while (i-- > 0) {
			if (!f(array[i]))
				array.remove(array[i]);
		}
		return array;
	}

	public static inline function last<T>(a : Array<T>) return a[a.length - 1];

	public static inline function max<T>(a : Array<T>, f : T -> Int) {
		if (a.empty()) return null;
		var max = Const.INT_MIN;
		var emax = null;
		for (e in a) {
			var v = f(e);
			if (v > max) {
				max = v;
				emax = e;
			}
		}
		return emax;
	}
}

#end