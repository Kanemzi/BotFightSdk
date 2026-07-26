package botfight.core;

// @todo find a way to haxe a "permanant" state that will be save only once
// like terrain gen. Currently, the whole GameState is saved for every turn for replay
// I have to save the whole state because some games implementations may not be deterministic
// If I could ensure that, I could only save the first state and player actions
// @todo think about a "state" authority for every n turns, the other turns are compupted from preview state and player actions

import botfight.core.Player;

typedef SUID = Int;

abstract class State implements hxbit.Serializable {
	@:s public var id(default, null) : SUID;
	@:allow(botfight.core.WeakRef) @:noPrivateAccess @:s var __alive(default, null) = true; 
	public inline function kill() __alive = false;
	
	public function new() {
		id = __uid; // we initialize the stable id of a state as it's first uid
	}

	/**
		Recursive iteration of all the sub states of [this]
	*/
	public function iterStates(f : (State, path : String) -> Void) : Void {
		function iter(s : State, _, p : String) : Bool {
			f(s, p);
			for (field in getAllFields(s)) {
				var v = Reflect.field(s, field);
				walk(v, null, '$p.$field', iter);
			}
			return true;
		}
		walk(this, null, iter);
	}

	public function equals(o : State) : Bool {
		if (o == null) return false;
		function iter(a : State, b : State, p : String) : Bool {
			return walkFields(a, b, p, getAllFields, iter);
		}
		return walk(this, o, iter);
	}

	static function getAllFields(o : Dynamic) {
		var fields = Type.getInstanceFields(Type.getClass(o));
		fields.keep(f -> {
			if (f.length == 0) return false;
			if (f == "__uid") return false;
			var v = Reflect.field(o, f);
			if (Reflect.isFunction(v)) return false;
			return true;
		});
		return fields;
	}

	/**
		Walks recursively either on one or two values. If [b] is set, return whether the two values are equal
	*/
	static function walk(a : Dynamic, b : Null<Dynamic>, ?path : String, f : (State, Null<State>, String) -> Bool) : Bool {		
		if (a == null)
			return b == null;
		
		final comp = b != null;
		path ??= "";

		var type = Type.typeof(a);
		if (comp && !Type.enumEq(type, Type.typeof(b)))
			return false;

		var ast = Std.downcast(a, State);
		if (ast != null)
			return f(ast, Std.downcast(b, State), path);

		var awr = Std.downcast(a, WeakRef);
		if (awr != null) {
			if (comp)
				return awr.get().id == Std.downcast(b, WeakRef)?.get().id;
			else
				return true;
		}

		switch (type) {
			case TClass(Array):
				var aarr = Std.downcast(a, Array);
				var barr = Std.downcast(b, Array);
				if (comp && aarr.length != barr.length)
					return false;
				else {
					var eq = true;
					for (i in 0...aarr.length) {
						var ai = aarr[i];
						var bi = barr != null ? barr[i] : null;
						if (!walk(ai, bi, '$path[$i]', f)) eq = false;
					}
					return eq;
				}

			case TClass(haxe.ds.StringMap | haxe.ds.IntMap | haxe.ds.Int64Map | haxe.ds.ObjectMap | haxe.ds.EnumValueMap):
				// @todo ensure map iteration is deterministic on hl
				var amap : haxe.Constraints.IMap<Dynamic, Dynamic> = cast a;
				var bmap : haxe.Constraints.IMap<Dynamic, Dynamic> = cast b;
				if (comp && bmap.keys().exists(k -> !amap.exists(k)))
					return false;
				else {
					var eq = true;
					for (k => va in amap) {
						if (comp && !bmap.exists(k)) eq = false;
						var bv = comp ? bmap.get(k) : null;
						if (!walk(va, bv, '$path[$k]', f)) eq = false;
					}
					return eq;
				}

			case TClass(Std.downcast(a, hxbit.Serializable.AnySerializable) => v) if (v != null):
				return walkFields(v, b, path, getAllFields, f);

			case TObject:
				return walkFields(a, b, path, Reflect.fields, f);

			case TEnum(_):
				if (comp && Type.enumIndex(a) != Type.enumIndex(b))
					return false;
				else {
					var pa = Type.enumParameters(a);
					var pb = comp ? Type.enumParameters(b) : null;
					final ct = haxe.EnumTools.EnumValueTools.getName(a);
					return walk(pa, pb, '$path#$ct', f);
				}

			default:
				return a == b;
		}
	}

	static function walkFields(
		a : Dynamic, 
		b : Dynamic, 
		path : String, 
		getFields : Dynamic -> Array<String>, 
		f : (State, Null<State>, String) -> Bool
	) : Bool {
		final afs = getFields(a);
		final bfs = getFields(b);
		if (b != null && bfs.exists(f -> afs.has(f)))
			return false;
		else {
			var eq = true;
			for (field in afs) {
				if (!bfs.has(field)) eq = false;
				var va = Reflect.field(a, field);
				var vb = b != null ? Reflect.field(b, field) : null;
				if (!walk(va, vb, '$path.$field', f)) eq = false;
			}
			return eq;
		}
	}
}

class WeakRef<T : State> {
	@:s var ref : T;
	public function new(ref : T) this.ref = ref;
	public function get() return ref?.__alive ? ref : null;
}

// @todo implements "PartialState" that has function to resolve it to a full state
abstract class GameState extends State {
	public abstract function serializeForPlayer(pid : PlayerId) : Array<String>;
}