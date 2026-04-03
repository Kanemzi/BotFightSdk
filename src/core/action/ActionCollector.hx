package core.action;

import core.Exception.InvalidActionException;
import core.GameServer;

using Lambda;

typedef ActionCond<Ta : EnumValue> = Ta -> Bool;

enum TurnActionProfile<Ta : EnumValue> {
    Fixed(n : Int, ?cond : ActionCond<Ta> );
    Until(end : ActionCond<Ta>, ?max : Int, ?cond : ActionCond<Ta>);
    Sequence(s : Array<TurnActionProfile<Ta>>);
}

abstract ActionCollector<Ta : EnumValue>(TurnActionProfile<Ta>) from TurnActionProfile<Ta> to TurnActionProfile<Ta> {
    public function new(v) { this = v; }
    public function collect(reader : Void -> Ta) : Array<Ta> {
        function validate(a : Ta, ?cond : ActionCond<Ta>) {
            if (cond != null && !cond(a)) // @todo send an error message explaining the mistake to the player based on the collector structure
                throw new InvalidActionException('Unexepected action "${ActionParser.toString(a)}"');
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