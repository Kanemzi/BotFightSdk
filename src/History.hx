import Player.ActionsResult;

@:generic
class HistoryTurn<Ts : GameState, Ta : EnumValue> implements hxbit.Serializable {
	@:s @:noPrivateAccess var actions : Array<ActionsResult<Ta>>;
	@:s @:noPrivateAccess var _state : GameState;

	public function new(state : Ts, actions : Array<ActionsResult<Ta>>) {
		this.actions = actions;
		_state = state;
	}

	public var state(get, never) : Ts;
	function get_state() return cast _state;
}

@:publicFields
class HistoryPlayer implements hxbit.Serializable {
	@:s var name : String;
	@:s var rank : Int;
	public function new(name : String, rank : Int) {
		this.name = name;
		this.rank = rank;
	}
}

@:publicFields @:generic
class History<Ts : GameState, Ta : EnumValue> implements hxbit.Serializable {
	@:s var version : String;
	@:s var players : Array<HistoryPlayer>;
	@:s var turns : Array<HistoryTurn<Ts, Ta>>;
	
	var length(get, never) : Int;
	function get_length() return turns.length;

	function new(v : String, pnames : Array<String>) {
		version = v;
		players = pnames.map(n -> new HistoryPlayer(n, -1));
		turns = [];
	}

	function addTurn(actions : Array<ActionsResult<Ta>>, state : Ts) {
		turns.push(new HistoryTurn(state, actions));
	}
}