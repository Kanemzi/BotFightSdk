package macros;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

class GameServerMacros {
	#if macro
	public static function build() : Array<Field> {
		var fields = Context.getBuildFields();
		var cl = Context.getLocalClass().get().

		var createField : Field = {
			name: "_",
			access: [APrivate, AStatic],
			kind: FVar(macro : Bool, macro {
				register($e{cl.name}, $p{[cl.pack, cl.name]});
			}),
			pos: Context.currentPos(),
		}
		
		fields.push(createField);

		return fields;
	}
	#end
}