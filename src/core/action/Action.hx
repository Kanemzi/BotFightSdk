package core.action;

typedef Word = String;
typedef Action = EnumValue;

@:autoBuild(core.Macros.buildActionParser())
abstract class ActionParser<Ta : Action> {
	public abstract function parseAction(action : String) : Ta; // @auto generated
    
	public static function toString(action : EnumValue) {
		var name = action.getName().toUpperCase();
		var params = Type.enumParameters(action).map(Std.string);
		return [name].concat(params).join(" ");
	}
}