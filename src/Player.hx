
class Player<TAction : EnumValue> {
	public var id(default, null) : Int;
	public var name(default, null) : String;
	var process : sys.io.Process;

    public function new(id, name, path) {
        this.id = id;
        this.name = name;
		process = new sys.io.Process('hl $path');
    }

	var history : Array<TAction>;

	public function getLastAction() : TAction {
		if( history.length == 0 ) return null;
		return history[history.length - 1];
	}
}