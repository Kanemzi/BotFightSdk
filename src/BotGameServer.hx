import GameServer;

enum Action {
	Wait;
	Move(x: Int, y: Int);
    Give(id : Int, amount : Int);
    Say(message : String);
}

@:structInit
class BotGamePlayerState implements hxbit.NetworkSerializable {
    @:s public var x : Int;
    @:s public var y : Int;
    @:s public var energy : Int;

    public function new(x, y, energy) {
        this.x = x;
        this.y = y;
        this.energy = energy;
    }
}

enum Tile {
    Empty;
    Food(amount : Int);
    Wall;
}

class BotGameState extends GameState {
    @:s public var players : Array<BotGamePlayerState>;
    @:s public var grid : Array<Tile>;

    public function new() {}

    function serializeForPlayer<TAction :EnumValue>(player : Player<TAction>) : String {
        return "";
    }
}

class BotGameServer extends GameServer<BotGameState, Action> {
    public static inline final WIDTH = 16;
    public static inline final HEIGHT = 7;
    public static inline final START_ENERGY = 10;

	public function new(args : Array<String>) {
		super(args, {
            minPlayers : 2,
            maxPlayers : 2,
            firstTurnTimeout : 1000,
            turnTimeout : 50,
            turnModel : TurnModel.SimultaneousTurn,
        });
	}

	function init() : BotGameState {
        var state = new BotGameState();
        state.grid = [for (_ in 0...WIDTH * HEIGHT) Empty];
        state.players = [for (i in 0...players.length) {
            new BotGamePlayerState(
                Std.int((HEIGHT - 1) / 2),
                i == 0 ? 1 : WIDTH - 2,
                START_ENERGY,
            );
        }];

		return state;
	}

	function update(state : BotGameState) : Void {
        for( p in state.players ) {
            p.x += Std.random(3) - 1;
        }
	}

    public function getDefaultAction() return Wait;
    public function getExpectedActionCount(player : Player<Action>) return 1;

	public static function main() {
		new Runner(BotGameServer, Sys.args());
	}
}