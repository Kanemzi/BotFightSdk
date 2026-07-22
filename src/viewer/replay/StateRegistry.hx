package viewer.replay;

import core.History;
import core.GameState.SUID;
import core.GameState.State;

/**
	Replays consists of duplicated GameStates for each turn, thus we can't directly
	bind EventView to State references since events might last multiple turns while
	State references last only one turn. For this reason, a VisualEvent can only store a
	SUID referencing the state. So that references to the associated State are resolved
	each update of the EventView (with a SUID, for a specific turn we can then resolve the
	references to both previous and current turn State to interpolate between them).

	Therefore we need to store all the state references bound to a specific SUID in a
	registry. That is then passed to the EventView
*/
public class StateRegistry {
	var history : History<GameState, EnumValue>;
	var entries : Map<SUID, RegistryEntry>;
	
	public function new(history : History<GameState, EnumValue>) {
		this.history = history;
		entries = new Map();
		for (i in 0...history.length) {
			var gs = history.turns[i].state;
			registerRefs(gs, i);	
		}
	}

	// @todo try to use @:rtti instead
	function registerRefs(gs : GameState, turn : Int) {
		var paths : Map<SUID, Array<String>>= [];
		function addRef(st : State, path : String) {
			/* Ensuring no state has multiple owners at the same time */
			var ps = paths.get(st.id);
			final exists = ps != null;
			if (ps == null) {
				ps = [];
				paths.set(st.id, ps);
			}
			ps.push(path);
			
			if (exists) {
				final cl = Type.getClassName(Type.getClass(st));
				var err = '$cl(${st.id}) had multiple owners on turn $turn. Consider using WeakRef<State> on one of these paths :';
				for (p in ps) err += '\n\t- $p';
				throw err // @todo maybe show a warning instead. Or find multiple owner issues at compile time 
			}

			/* Registering the new ref */
			var e = entries.get(st.id);
			if (e == null) {
				e = {
					id : st.id,
					firstTurn : turn;
					refs : [];
				}
				entries.set(st.id, e);
			}
			e.refs[turn - firstTurn] = st;
		}
		final gsName = Type.getClassName(Type.getClass(gs));
		registerRec(gs, gsName, addRef);
	}

	function registerRec(o : Dynamic, path : String, add : (State, String) -> Void ) {
		
		var st = Std.downcast(o, State);
		if (st != null) add(st, path);

		for (fname in Reflect.fields(o) ) {
			var v = Reflect.field(o, fname);
			var t = Type.typeof(v);
			inline function rec(v) registerRec(v, path + '.$fname', add);

			switch (t) {
				case TObject:
					rec(v);
				case TClass(Array): // @todo ensure @:s Arrays can cast to array implicitly
					var a = Std.downcast(v, Array);
					for (e in a) rec(e);
				case TClass(Map): // @todo implement for other map types
					var m = Std.downcast(v, Map);
					for (k=>e in m) rec(e);
				case TClass(Std.downcast(v, hxbit.Serializable.AnySerializable) => s) if (s != null):
					rec(s);
				case TEnum(e):
					var ps = Type.enumParameters(v);
					for( _ => p in ps ) rec(p);
				default:
			}
		}
	}

	public inline function resolve(id : SUID, turn : Int) return entries.get(id).at(turn);
}

typedef RegistryEntryImpl = {
	var id : SUID;
	var firstTurn : Int;
	var refs : Array<State>;
}

abstract RegistryEntry(RegistryEntryImpl) from RegistryEntryImpl {

	public var lastTurn(get, never) : Int;
	inline function get_lastTurn() return firstTurn + refs.length - 1;

	public inline function at(turn : Int) {
		return (refs != null && turn >= firstTurn && turn <= lastTurn)
			? refs[turn - firstTurn]
			: null;
	}
}