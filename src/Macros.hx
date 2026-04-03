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
			case TInst(_.get().superClass.params => params, _) if (params.length > 0):
				var e = null;
				for (p in params) switch (p) {
					case TEnum(_, _): e = p;
					default:
				}
				e;
			default:
				Context.error('Invalid GameServer implementation : $type', pos);
		};

		if (actionType == null)
			return fields;

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
				
				var nullable = false;
				t = switch (t) { // unnullabilify the type
					case TAbstract(_.get().name => "Null", [st]):
						nullable = true; 
						st;
					default: t;
				}

				inline function unsupportedType() Context.error('Unsupported parameter type for $name(${params[i].name}) : ${t.getParameters()[0]}', pos);
				switch (t) {
					case TAbstract(at, _):
						switch (at.get().name) {
							case "Int": 
								patterns.push("(-?\\d+)");
								values.push(macro Std.parseInt(re.matched(${index})));
							default: unsupportedType();
						}
					case TInst(ti, _):
						switch (ti.get().name) {
							case "String":
								if (i != params.length - 1)
									Context.error('Unexpected parameter $name(${params[i].name}). String param should always be the last', pos);
								var m = nullable ? "*" : "+";
								var pattern = '(.$m)';
								if (nullable)
									pattern = '?$pattern';
								patterns.push(pattern);
								values.push(macro {
									var s = re.matched(${index});
									($v{nullable} && s == "") ? null : s;  
								});
							default: unsupportedType();
						}
					case TType(tt, _):
						switch (tt.get().name) {
							case "Word":
								patterns.push("(\\w+)");
								values.push(macro re.matched(${index}));
							default: unsupportedType();
						}
					default:
						unsupportedType();
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
		
		var comp = Context.toComplexType(actionType);
		
		var parseFn = {
			name: "parseAction",
			access: [],
			kind: FFun({
				args: [{
					name: "action",
					type: macro : String,
					opt: false,
				}],
				ret: comp,
				expr: macro {
					if (action == null) return null;
					action = action.trim();
					$b{matchers};
					return null;
				}
			}),
			pos: pos,
		};


		// @todo just generate a cast on null instead to avoid creating a usedless field
		fields.push({
			name : "__action",
			access: [AStatic, AInline, AFinal],
			kind: FVar(macro : hxbit.Serializable.SerializableEnum<$comp>, macro null),
			pos: pos,
		});

		fields.push(parseFn);
		return fields;
	}
	#end
}