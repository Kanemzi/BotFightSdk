package server.behaviour;

import server.behaviour.Node;
import server.behaviour.Behaviour.BehaviourContext;

abstract class Decorator extends Node {
	final child : Node;
	public function new(child : Node) {
		super();
		this.child = child;
	}

	override function close(ctx : BehaviourContext) {
		ctx.clear(id);
		child.close(ctx);
	}
}

class Invert extends Decorator {
	function tick(ctx : BehaviourContext) {
		return switch (child.tick(ctx)) {
			case Success : Failure;
			case Failure : Success;
			case Running : Running;
		}
	}
}

class Repeat extends Decorator {
	final n : Null<Int>;
	var infinite(get, never) : Bool;
	inline function get_infinite() return n == null;

	public function new(child : Node, ?n : Int) {
		super(child);
		this.n = n;
	}

	function tick(ctx : BehaviourContext) {
		var i = ctx.get(id) ?? 0;
		while (infinite || i < n) {
			switch (child.tick(ctx)) {
				case Success:
					i++;
					return Running;
				case Failure:
					ctx.clear(id);
					return Failure;
				case Running:
					ctx.set(id, i);
					return Running;
			}
		}
		ctx.clear(id);
		return Success;
	}
}

class RepeatUntil extends Decorator {
	function tick(ctx : BehaviourContext) {
		return switch (child.tick(ctx)) {
			case Success : Success;
			case Failure, Running : Running;
		}
	}
}

@:forward abstract RepeatWhile(RepeatUntil) {
	public inline function new(child : Node) {
		this = new RepeatUntil(new Invert(child));
	}
}