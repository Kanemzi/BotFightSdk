package botfight.viewer.replay;

import botfight.core.History;
import botfight.core.GameState;
import botfight.core.GameState.SUID;
import botfight.core.GameState.State;
import botfight.core.action.Action;

/**
	Replays consists of duplicated GameStates for each turn, thus we can't directly
	bind EventView to State references since events might last multiple turns while
	State references last only one turn. For this reason, a VisualEvent can only store a
	SUID referencing the state. So that references to the associated State are resolved
	each update of the EventView (with a SUID, for a specific turn we can then resolve the
	references to both previous and current turn State to interpolate between them).

	Therefore we need to store all the state references bound to a specific SUID in a
	registry. That is then passed to the EventView

	// @todo some ids seem to be broken (seem to be vectors)
	// @todo could be pack and optimize this memory ? check object size ?
*/
class StateRegistry {
	var entries : Map<SUID, RegistryEntry>;
	
	public function new<Ts : GameState>(history : History<Ts, Action>) {
		entries = new Map();
		for (i in 0...history.length) {
			var gs = history.turns[i].state;
			registerRefs(gs, i);	
		}
	}

	function registerRefs<Ts : GameState>(gs : Ts, turn : Int) {
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
				throw err; // @todo maybe show a warning instead. Or find multiple owner issues at compile time 
			}

			/* Registering the new ref */
			var e = entries.get(st.id);
			if (e == null) {
				e = {
					id : st.id,
					firstTurn : turn,
					refs : [],
				}
				entries.set(st.id, e);
			}
			e.refs[turn - e.firstTurn] = st;
		}
		gs.iterStates(addRef);
	}

	public inline function get(id : SUID) return entries.get(id);
	public inline function resolve(id : SUID, turn : Int) return get(id)?.at(turn);
}

@:structInit
@:allow(botfight.viewer.replay.StateRegistry)
class RegistryEntry {
	var id : SUID;
	var firstTurn : Int;
	var refs : Array<State>;

	public var lastTurn(get, never) : Int;
	inline function get_lastTurn() return firstTurn + refs.length - 1;

	public inline function at(turn : Int) {
		return (refs != null && turn >= firstTurn && turn <= lastTurn)
			? refs[turn - firstTurn]
			: null;
	}
}