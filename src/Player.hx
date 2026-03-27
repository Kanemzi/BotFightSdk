
class Player<TAction : EnumValue> {
	public var id(default, null) : Int;
	public var name(default, null) : String;

	var history : Array<TAction>;

	public function getLastAction() : TAction {
		if( history.length == 0 ) return null;
		return history[history.length - 1];
	} 
}