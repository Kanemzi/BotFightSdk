package core;

// @todo find a way to haxe a "permanant" state that will be save only once
// like terrain gen. Currently, the whole GameState is saved for every turn for replay
// I have to save the whole state because some games implementations may not be deterministic
// If I could ensure that, I could only save the first state and player actions
// @todo think about a "state" authority for every n turns, the other turns are compupted from preview state and player actions

import core.Player;

typedef SUID = Int;

abstract class State implements hxbit.Serializable {
	@:s public var id(default, null) : SUID;
	@:allow(core.WeakRef) @:noPrivateAccess @:s var __alive(default, null) = true; 
	public inline function kill() __alive = false;
	
	public function new() {
		id = __uid; // we initialize the stable id of a state as it's first uid
	}
}

class WeakRef<Ts : State> {
	@:s var ref : Ts;
	public function new(ref : Ts) this.ref = ref;
	public function get() return ref?.__alive ? ref : null;
}

// @todo implements "PartialState" that has function to resolve it to a full state
abstract class GameState extends State {
	public abstract function serializeForPlayer(pid : PlayerId) : Array<String>;
}