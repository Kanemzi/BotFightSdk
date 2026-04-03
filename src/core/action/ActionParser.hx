package core.action;

typedef Word = String;

@:autoBuild(core.Macros.buildActionParser())
abstract class ActionParser<Ta : EnumValue> {
	public abstract function parseAction(action : String) : Ta; // @auto generated
    
	public static function toString(action : EnumValue) {
		var name = action.getName().toUpperCase();
		var params = Type.enumParameters(action).map(Std.string);
		return [name].concat(params).join(" ");
	}
}