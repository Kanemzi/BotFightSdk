package server.behaviour;

import server.behaviour.Node;
import server.behaviour.Decorator;
import server.behaviour.Composite;

typedef NodeKey = Int;

@:allow(server.behaviour.Node)
abstract class BehaviourContext {
	@:noPrivateAccess var _state : Map<NodeKey, Dynamic>;
	public function new() _state = new Map();

	inline final function get(node : NodeKey) return _state.get(node);
	inline final function set(node : NodeKey, v : Dynamic) _state.set(node, v);
	inline final function clear(node : NodeKey) _state.remove(node);
	inline final function reset() _state.clear();
}

@:publicFields
class Behaviour {
	static inline function fallback(children : Array<Node>, reactive = false) : Fallback {
		return new Fallback(children, reactive);
	}

	static inline function sequence(children : Array<Node>, reactive = false) : Sequence {
		return new Sequence(children, reactive);
	}

	static inline function invert(child : Node) : Invert {
		return new Invert(child);
	}

	static inline function repeat(child : Node) : Repeat {
		return new Repeat(child);
	}

	static inline function repeatUntil(child : Node) : RepeatUntil {
		return new RepeatUntil(child);
	}

	static inline function repeatWhile(child : Node) : RepeatWhile {
		return new RepeatWhile(child);
	}

	static inline function action(f : BehaviourContext -> Status) : Action {
		return new Action(f);
	}

	static inline function cond(f : BehaviourContext -> Bool) : Condition {
		return new Condition(f);
	}
}

abstract NodeBuilder(Node) from Node to Node {

	@:from
	static inline function fromAction(f : BehaviourContext -> Status) : NodeBuilder {
		return cast new Action(f);
	}

	@:from
	static inline function fromCond(f : BehaviourContext -> Bool) : NodeBuilder {
		return cast new Condition(f);
	}

	static function _sequence(a : NodeBuilder, b : NodeBuilder, reactive : Bool) : NodeBuilder {
		var s = cast Std.downcast(cast a, _Sequence);
		if (s != null) {
			s.children.push(cast b);
			return cast new Sequence(s.children, reactive);
		}
		return cast new Sequence([cast a, cast b], reactive);
	}

	@:op(A >> B) static inline function sequence(a : NodeBuilder, b : NodeBuilder) : NodeBuilder {
		return _sequence(a, b, false);
	}

	@:op(A >>> B) static function reactiveSequence(a : NodeBuilder, b : NodeBuilder) : NodeBuilder {
		return _sequence(a, b, true);
	}

	static function _fallback(a : NodeBuilder, b : NodeBuilder, reactive : Bool) : NodeBuilder {
		var f = Std.downcast(a, Fallback);
		if (f != null) {
			f.children.push(cast b);
			return cast new Fallback(f.children, reactive);
		}
		return cast new Fallback([cast a, cast b], reactive);
	}

	@:op(A | B) static function fallback(a : NodeBuilder, b : NodeBuilder) : NodeBuilder {
		return _fallback(a, b, false);
	}

	@:op(A || B) static function reactiveFallback(a : NodeBuilder, b : NodeBuilder) : NodeBuilder {
		return _fallback(a, b, true);
	}

	@:op(!A) function invert() : NodeBuilder {
		return cast new Invert(this);
	}

	@:op(A * B)
	function repeat(n : Int) : NodeBuilder {
		return cast new Repeat(this, n);
	}
}