package cogpit.core;

typedef SUID = Int;

abstract class State implements hxbit.Serializable {
	@:s public var id(default, null) : SUID;
	@:allow(cogpit.core.WeakRef) @:noPrivateAccess @:s var __alive(default, null) = true; 
	public inline function kill() __alive = false;
	
	public function new() {
		id = __uid; // we initialize the stable id of a state as it's first uid
	}

	/**
		Recursive iteration of all the sub states of [this]
	*/
	public function iterStates(f : (State, path : String) -> Void) : Void {
		function iter(s : State, _, p : String, _) : Bool {
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
		function iter(a : State, b : State, p : String, _) : Bool {
			return walkFields(a, b, p, getAllFields, iter);
		}
		return walk(this, o, iter);
	}

	public function optimizeDelta(prev : GameState) {
		if (prev == null) return;
		// @todo call this as the game is simulated to avoid a long pass at the end flow is:
		//	new = cloneState(prev)
		//  update(new)
		//  new.optimizeDelta(prev)
		// @todo pass a default set for the case GameState is exactly the same
		function iter(s : State, ps : State, path: String, set : Null<Dynamic -> Void>) {
			if (ps == null) // state appeared in this transition
				return false;

			if (s.equals(ps)) {
				if (set != null) set(ps);
				return true;
			}

			walkFields(s, ps, path, getAllFields, iter);
			return false;
		}

		walk(this, prev, iter);
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
		The optional [set] function allows remapping states within the state while iterating.
	*/
	static function walk(
		a : Dynamic, 
		b : Null<Dynamic>, 
		?path : String, 
		?set : (Dynamic -> Void),
		f : (State, Null<State>, String, Null<Dynamic -> Void>) -> Bool
	) : Bool {		
		if (a == null)
			return b == null;
		
		final comp = b != null;
		path ??= "";

		var type = Type.typeof(a);
		if (comp && !Type.enumEq(type, Type.typeof(b)))
			return false;

		var ast = Std.downcast(a, State);
		if (ast != null)
			return f(ast, Std.downcast(b, State), path, set);

		var awr = Std.downcast(a, WeakRef);
		if (awr != null) {
			if (comp)
				return awr.get().id == Std.downcast(b, WeakRef)?.get().id;
			else
				return true;
		}

		switch (type) {
			case TClass(Array):
				var aarr : Array<Dynamic> = Std.downcast(a, Array);
				var barr : Array<Dynamic> = Std.downcast(b, Array);
				var eq = comp && aarr.length == barr.length;

				// If the array contains states, their index might have change but we can still remap them using their id as a reference instead of the index
				var byUid : Map<SUID, State> = null;
				if (barr != null) {
					for (i in 0...barr.length) {
						var s = Std.downcast(barr[i], State);
						if (s == null) continue; 
						(byUid ??= new Map()).set(s.id, s);
					}
				}

				for (i in 0...aarr.length) {
					var ai = aarr[i];
					var bi = barr == null ? null : {
						var as = Std.downcast(ai, State);
						(as == null ? null : byUid?.get(as.id)) ?? barr[i];
					}
					if (comp && bi == null && ai != null) { // arrays are probably not the same size, just consider them not equal
						eq = false;
						continue;
					}
					final set = v -> aarr[i] = v;
					if (!walk(ai, bi, '$path[$i]', set, f)) eq = false;
				}
				
				return eq;

			case TClass(haxe.ds.StringMap | haxe.ds.IntMap | haxe.ds.Int64Map | haxe.ds.ObjectMap | haxe.ds.EnumValueMap):
				// @todo ensure map iteration is deterministic on hl
				var amap : haxe.Constraints.IMap<Dynamic, Dynamic> = cast a;
				var bmap : haxe.Constraints.IMap<Dynamic, Dynamic> = cast b;
				if (comp && bmap.keys().exists(k -> !amap.exists(k)))
					return false;
				else {
					var eq = true;
					// @todo is it ok to swap map items during iteration ?
					for (k => va in amap) {
						if (comp && !bmap.exists(k)) eq = false;
						var bv = comp ? bmap.get(k) : null;
						final set = v -> amap.set(k, v);
						if (!walk(va, bv, '$path[$k]', set, f)) eq = false;
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
					var eq = true;
					var dirty = false;
					for (i in 0...pa.length) {
						var ai = pa[i];
						var bi = pb != null ? pb[i] : null;
						final set = v -> { pa[i] = v; dirty = true; }
						if (!walk(ai, bi, '$path[$i]', set, f)) eq = false;
					}
					if (dirty && set != null)
						set(Type.createEnum(Type.getEnum(a), ct, pa));
					return eq;
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
		f : (State, Null<State>, String, Null<Dynamic -> Void>) -> Bool
	) : Bool {
		final afs = getFields(a);
		final bfs = b != null ? getFields(b) : null;
		if (b != null && bfs.exists(f -> !afs.has(f)))
			return false;
		else {
			var eq = true;
			for (field in afs) {
				if (!bfs?.has(field)) eq = false;
				var va = Reflect.field(a, field);
				var vb = b != null ? Reflect.field(b, field) : null;
				final set = v -> Reflect.setField(a, field, v);
				if (!walk(va, vb, '$path.$field', set, f)) eq = false;
			}
			return eq;
		}
	}
}

// @todo improve and test this
class WeakRef<T : State> implements hxbit.Serializable {
	@:s var ref : State;
	public function new(ref : T) this.ref = ref;
	public function get() : T return ref?.__alive ? cast ref : null;
}

abstract class GameState extends State {
}