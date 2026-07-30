package server.behaviour;

import server.behaviour.Behaviour.BehaviourContext;

enum Status { Success; Failure; Running; }

abstract class Node {
	static var _nextId : Int = 0;
	final id : Int;

	public function new() id = _nextId ++;
	public abstract function tick(ctx : BehaviourContext) : Status;
	public function close(ctx : BehaviourContext) ctx.clear(id);
}

class Action extends Node {
	final f : BehaviourContext -> Status;

	public function new(f : BehaviourContext -> Status) {
		super();
		this.f = f;
	}

	function tick(ctx : BehaviourContext) return f(ctx);
}

class Condition extends Node {
	final f : BehaviourContext -> Bool;

	public function new(f : BehaviourContext -> Bool) {
		super();
		this.f = f;
	}

	function tick(ctx : BehaviourContext) return f(ctx) ? Success : Failure;
}