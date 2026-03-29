
class Player<TAction : EnumValue> {
	public var id(default, null) : Int;
	public var name(default, null) : String;

    public function new(id, name) {
        this.id = id;
        this.name = name;
    }

	var history : Array<TAction>;

	public function getLastAction() : TAction {
		if( history.length == 0 ) return null;
		return history[history.length - 1];
	} 
}