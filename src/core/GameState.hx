package core;

// @todo find a way to haxe a "permanant" state that will be save only once
// like terrain gen. Currently, the whole GameState is saved for every turn for replay
// I have to save the whole state because some games implementations may not be deterministic
// If I could ensure that, I could only save the first state and player actions
// @todo think about a "state" authority for every n turns, the other turns are compupted from preview state and player actions

interface State extends hxbit.Serializable {}

// @todo implements "PartialState" that has function to resolve it to a full state
abstract class GameState implements State {
	// abstract function serializeForPlayer<Ta :EnumValue>(player : Player<Ta>) : Array<String>;
}