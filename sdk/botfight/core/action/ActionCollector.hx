package botfight.core.action;

import botfight.core.Exception.InvalidActionException;
import botfight.core.action.Action;
import botfight.utils.Result;

using Lambda;

typedef ActionCond<Ta : Action> = Ta -> Result<Bool, String>;
typedef ActionCheck<Ta : Action> = Ta -> Bool;

enum TurnActionProfile<Ta : Action> {
	Fixed(n : Int, ?cond : ActionCond<Ta> );
	Until(end : ActionCheck<Ta>, ?max : Int, ?cond : ActionCond<Ta>);
	Sequence(s : Array<TurnActionProfile<Ta>>);
}

abstract ActionCollector<Ta : Action>(TurnActionProfile<Ta>) from TurnActionProfile<Ta> to TurnActionProfile<Ta> {
	public function new(v) { this = v; }
	public function collect(reader : Void -> Ta) : Array<Ta> {
		function validate(a : Ta, ?cond : ActionCond<Ta>) {
			if (cond != null) switch (cond(a)) {
				case Ok(_):
				case Error(e):
					throw new InvalidActionException('Unexepected action "${ActionParser.toString(a)}" : $e');
			}
			return a;
		}
		final next = (?cond : ActionCond<Ta>) -> validate(reader(), cond);
		
		// @todo don't consume Until(end) action, so that it can be used 
		return switch (this) {
			case Fixed(n, cond): [for (_ in 0...n) next(cond)];
			case Until(end, max, cond):
				var actions = [];
				while (true) {
					if (max != null && actions.length >= max)
						break;
					final a = next(cond);
					actions.push(a);
					if (end != null && end(a))
						break;
				}
				actions;
			case Sequence(seq): seq.flatMap(s -> new ActionCollector(s).collect(reader));
		}
	}
}