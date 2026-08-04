package cogpit.utils;

import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.ExprTools;

class Assert {
    public static macro function assert(cond : Expr, ?msg : ExprOf<String>) : Expr {
        final condStr = ExprTools.toString(cond);
        final meth = Context.getLocalMethod();
        final loc = haxe.macro.PositionTools.toLocation(cond.pos);
        final posInf = '${loc.file}@$meth:${loc.range.start.line}';

        return macro @:pos(cond.pos) if (!$cond) {
            var desc : String = $msg;
            throw "Assertion failed (" + $v{posInf} + ") : " + $v{condStr}
                + (desc != null ? '\n$desc' : "");
        }
    }
}