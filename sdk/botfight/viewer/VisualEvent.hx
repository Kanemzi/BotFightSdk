package botfight.viewer;

import botfight.core.GameState.State;
import botfight.core.GameState.SUID;
import botfight.viewer.replay.StateRegistry.RegistryEntry;

typedef EventId = Int;

@:allow(botfight.viewer.TimelineRule)
@:allow(botfight.viewer.TimelineBuilder)
@color(0x60c7be)
class VisualEvent {
	public var id(default, null) : EventId = -1; // event ids will be given by the TimelineBuilder
	public var begin(default, null) : Float = -1;
	public var end(default, null) : Float = -1;
}

@color(0xc760a5)
class StateVisualEvent<T : State> extends VisualEvent {
	public var suid(default, null) : SUID;
	@:allow(botfight.viewer.TimelineBuilder) var ctx : RegistryEntry;

	var _cl : Class<T>;
	public function new(st : T) {
		this.suid = st.id;
		_cl = Type.getClass(st);
	}

	public function resolve(turn : Int) : T {
		var st = ctx?.at(turn);
		return Std.downcast(st, _cl);
	}
}