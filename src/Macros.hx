import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;

class Macros {
	#if macro
	macro public static function buildActionParser() : Array<Field> {
		final pos = Context.currentPos();
		var fields = Context.getBuildFields();
		var type = Context.getLocalType();
		
		var actionType : Type = switch (type) {
			case TInst(_.get().superClass.params => params, _) if (params.length >= 2):
				var e = params[1];
				switch (e) {
					case TEnum(_, _): e;
					default: Context.error('TAction should be an EnumValue', pos);
				}
			default:
				Context.error('Invalid GameServer implementation : $type', pos);
		};

		var consts = TypeTools.getEnum(actionType).constructs;

		var matchers : Array<Expr> = [];
		for (name => c in consts) {
			var patterns = [name.toUpperCase()];
			var values : Array<Expr> = [];

			var params = switch (c.type) {
				case TFun(args, _): args;
				default: [];
			};

			for (i in 0...params.length) {
				var t = params[i].t;
				var index : Expr = macro $v{i + 1};
				inline function unsupportedType() Context.error('Unsupported parameter type for $name(${params[i].name}) : ${t.getParameters()[0]}', pos);
				switch (t) {
					case TAbstract(at, _):
						switch (at.get().name) {
							case "Int": 
								patterns.push("(-?\\d+)");
								values.push(macro Std.parseInt(re.matched(${index})));
							default: unsupportedType();
						}
					case TInst(t, _):
						switch (t.get().name) {
							case "String":
								patterns.push("(.+)");
								values.push(macro re.matched(${index}));
							default: unsupportedType();
						}
					default: unsupportedType();
				}
			}

			var e = params.length == 0 ? macro $i{name} : macro $i{name}($a{values});
			var block : Expr = macro {
				var re = new EReg($v{'^${patterns.join(" ")}$'}, "");
				if (re.match(action)) {
					return $e;
				}
			}
			matchers.push(block);
		}
		
		var parseFn = {
			name: "parseAction",
			access: [],
			kind: FFun({
				args: [{
					name: "action",
					type: macro : String,
					opt: false,
				}],
				ret: Context.toComplexType(actionType),
				expr: macro {
					if (action == null) return null;
					action = StringTools.trim(action);
					$b{matchers};
					return null;
				}
			}),
			pos: pos,
		};

		fields.push(parseFn);
		return fields;
	}
	#end
}