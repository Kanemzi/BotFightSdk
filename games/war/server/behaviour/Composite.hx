package server.behaviour;

import server.behaviour.Node;
import server.behaviour.Behaviour.BehaviourContext;
import server.behaviour.Decorator.Invert;

@:allow(server.behaviour.NodeBuilder)
abstract class Composite extends Node {
	final children : Array<Node>;
	final reactive : Bool;

	public function new(children : Array<Node>, reactive = false) {
		super();
		this.children = children;
		this.reactive = reactive;
	}

	override function close(ctx : BehaviourContext) {
		ctx.clear(id);
		children.iter(c -> c.close(ctx));
	}
}

class Fallback extends Composite {
	function tick(ctx : BehaviourContext) {
		var last = ctx.get(id);
		var i = reactive ? 0 : last ?? 0;

		inline function closeLast() {
			if (reactive && last > i)
				children[last].close(ctx);
		}

		while (i < children.length) {
			switch (children[i].tick(ctx)) {
				case Success:
					closeLast();
					ctx.clear(id);
					return Success;
				case Failure:
					i++;
				case Running:
					closeLast();
					ctx.set(id, i);
					return Running;
			}
		}
		ctx.clear(id);
		return Failure;
	}
}

class Sequence extends Composite {
	function tick(ctx : BehaviourContext) {
		var last = ctx.get(id);
		var i = reactive ? 0 : last ?? 0;

		inline function closeLast() {
			if (reactive && last > i)
				children[last].close(ctx);
		}

		while (i < children.length) {
			switch (children[i].tick(ctx)) {
				case Success:
					i++;
				case Failure:
					closeLast();
					ctx.clear(id);
					return Failure;
				case Running:
					closeLast();
					ctx.set(id, i);
					return Running;
			}
		}
		ctx.clear(id);
		return Success;
	}
}
