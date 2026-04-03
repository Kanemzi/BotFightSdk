package utils;

@:generic class ArrayIterator<T> {
	final array:Array<T>;
	var current:Int = 0;
	public inline function new(array:Array<T>) { this.array = array; }
	public inline function hasNext() return current < array.length;
	public inline function next() return array[current++];
}

class IndexedLazyIteratorItem<T> {
	public var i : Int;
	public var v : T;
	public function new(i, v) {
		this.i = i;
		this.v = v;
	}
}

@:generic class IndexedLazyIterator<T> {
	public var it : Iterator<T>;
	public var i = 0;

	public function new(it: Iterator<T>) {
		this.it = it;
	}
  
	inline public function hasNext(): Bool { return it.hasNext(); }
	inline public function next(): IndexedLazyIteratorItem<T> { return inline new IndexedLazyIteratorItem(i++, it.next()); }
}

@:generic class FilterLazyIterator<T> {
	public var it : Iterator<T>;
	public var f: T -> Bool;
	public var nextItem: T;
	public var hasNextItem: Bool = false;

	inline public function new(it: Iterator<T>, f: T -> Bool) {
		this.it = it;
		this.f = f;
	}
  
	inline public function hasNext(): Bool {
		while (!hasNextItem && it.hasNext()) {
			var i = it.next();
			if (f(i)) {
				nextItem = i;
				hasNextItem = true;
			}
		}
		return hasNextItem;
	}

	inline public function next(): T {
		if (!hasNextItem) hasNext();
		hasNextItem = false;
		return nextItem;
	}
}

@:generic class MapLazyIterator<T, U> {
	public var it : Iterator<T>;
	public var f: T -> U;

	inline public function new(it: Iterator<T>, f: T -> U) {
		this.it = it;
		this.f = f;
	}
  
	inline public function hasNext(): Bool { return it.hasNext(); }
	inline public function next(): U { return f(it.next()); }
}

class UtilsIterators {

	public static inline function toIterator<T>(array: Array<T>) {
		return new ArrayIterator(array);
	}

	inline public static function collect<T>(iter: Iterator<T>) {
		var res = [];
		while (iter.hasNext()) res.push(iter.next());
		return res;
	}

	inline public static function filter<T>(iter: Iterator<T>, filter: T -> Bool) {
		return inline new FilterLazyIterator(iter, filter);
	}

	inline public static function map<T, U>(iter: Iterator<T>, filter: T -> U) {
		return inline new MapLazyIterator(iter, filter);
	}

	inline public static function count<T>(iter: Iterator<T>) {
		var n = 0;
		for (_ in iter) n++;
		return n;
	}

	inline public static function empty<T>(iter: Iterator<T>) {
		return iter.hasNext();
	}

	inline public static function find<T>(iter: Iterator<T>, f : T -> Bool ) {
		var it = iter.filter(f);
		return it.hasNext() ? it.next() : null;
	}

	inline public static function exists<T>(iter: Iterator<T>, f : T -> Bool) {
		return iter.filter(f).hasNext();
	}

	inline public static function has<T>(iter: Iterator<T>, item : T) {
		return iter.exists(i -> i == item);
	}

	inline public static function foreach<T>(iter: Iterator<T>, f : T->Bool) {
		for (i in iter) if (!f(i)) break;	
	}

	inline public static function fold<T, U>(iter: Iterator<T>, acc : U, f : (T, U) -> U) {
		for (x in iter) acc = f(x, acc);
		return acc;
	}

	inline public static function enumerate<T>(iter: Iterator<T>) {
		return new IndexedLazyIterator(iter);
	}

	inline public static function indexOf<T>(iter: Iterator<T>, item : T) : Int {
		var it = iter.enumerate().filter(e -> e.v == item);
		if (it.hasNext()) return -1;
		return it.next().i;
	}
}