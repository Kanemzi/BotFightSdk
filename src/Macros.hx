import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;

class Macros {
	#if macro
	macro public static function buildActionParser() : haxe.macro.ComplexType {
		var type = Context.getLocalType();
		final pos = Context.currentPos();
	   
		var actionType : Type = Context.follow(switch (type) {
			case TInst(_, params) if (params.length >= 2):
				var e = params[1];
				switch (e) {
					case TEnum(_, _): e;
					default: Context.error('TAction should be an EnumValue', pos);
				}
			default:
				Context.error('Invalid GameServer implementation', pos);
		});

		var consts = TypeTools.getEnum(actionType).constructs;

		//var ctype : ComplexType = Context.toComplexType(type);

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
				inline function unsupportedType() Context.error('Unsupported parameter type for $name(${params[i].name}) : ${t.getParameters()[0]}', pos);
				switch (t) {
					case TAbstract(at, _):
						switch (at.get().name) {
							case "Int": 
								patterns.push("(-?\\d+)");
								parsers.push(macro Std.parseInt(reg.matched(${i + 1})));
							default: unsupportedType();
						}
					case TInst(t, _):
						switch (t.get().name) {
							case "String":
								patterns.push("(\\S+)");
								parsers.push(macro reg.matched(${i + 1}));
							default: unsupportedType();
						}
					default: unsupportedType();
				}
			}

			var block = macro {
				var re = new EReg($v{'^${patterns.join(" ")}$'});
				if (re.match(action)) {
					return params.length == 0 ? $i{name} : $i{name}($a{values});
				}
			}

			Context.warning('OUT2 : ${patterns}', pos);
		}




		/*
		Context.defineType({
			pack: [],
			name: '${name}Tools',
			kind: TDClass(),
			pos: pos,
			fields: [{
				name: "parse",
				access: [APublic, AStatic],
				kind: FFun({
					args: [{
						name: "action",
						type: macro : String,
						opt: false,
					}],
					ret: Context.toComplexType(type),
					expr: macro {
						if (action == null) return null;
						action = StringTools.trim(action);
						return null;
					}
				}),
				pos: pos,
			}]
		});*/

		/*
		var parseFn = {
			name: "parse",
			access: [APublic, AStatic],
			kind: FFun({
				args: [{
					name: "action",
					type: macro : String,
					opt: false,
				}],
				ret: Context.toComplexType(type),
				expr: macro {
					if (action == null) return null;
					action = StringTools.trim(action);
					return null;
				}
			}),
			pos: pos,
		};

		fields.push(parseFn);
		*/
/*
		var constructs = switch (enumType) {
			case TEnum(e, _): e.get().constructs;
			default:
				Context.error("ActionParserBuilder must be used on an enum", pos);
				null;
		};

		var matchBlocks:Array<Expr> = [];

		for (name => c in constructs) {

			var upperName = name.toUpperCase();

			var paramTypes = switch (c.type) {
				case TFun(args, _): args;
				default: [];
			};

			var patternParts = [upperName];
			var buildArgs:Array<Expr> = [];

			for (i in 0...paramTypes.length) {

				var t = paramTypes[i].t;

				switch (t) {
					case TAbstract(a, _):
						var typeName = a.get().name;

						if (typeName == "Int") {
							patternParts.push("(-?\\d+)");
							buildArgs.push(macro Std.parseInt(re.matched(${i + 1})));
						} else if (typeName == "String") {
							patternParts.push("(\\S+)");
							buildArgs.push(macro re.matched(${i + 1}));
						} else {
							Context.error("Unsupported type: " + typeName, pos);
						}

					default:
						Context.error("Unsupported parameter type", pos);
				}
			}

			var pattern = "^" + patternParts.join("\\s+") + "$";

			var actionExpr = (paramTypes.length == 0)
				? macro $i{name}
				: macro $i{name}($a{buildArgs});

			var block = macro {
				var re = new EReg($v{pattern}, "i");
				if (re.match(action)) {
					return $actionExpr;
				}
			};

			matchBlocks.push(block);
		}

		var body = macro {
			if (action == null) return null;

			action = StringTools.trim(action);

			$b{matchBlocks}

			return null;
		};

		var parseField:Field = {
			name: "parseAction",
			access: [APublic, AStatic],
			kind: FFun({
				args: [
					{
						name: "action",
						type: macro:String
					}
				],
				expr: body,
				ret: null
			}),
			pos: pos
		};

		fields.push(parseField);
*/
		//return fields;
		return Context.toComplexType(type);
	}
	#end
}