import GameServer;

class BotGameView extends hxd.App {
    override function init() {
        var tf = new h2d.Text(hxd.res.DefaultFont.get(), s2d);
        tf.text = "Bot Game";
    }
}

enum Action {
	Wait;
	Move(x: Int, y: Int);
}

class BotGamePlayerState {	
}

class BotGameState extends GameState {
}

class BotGameServer extends GameServer<BotGameState, Action> {
	var view : BotGameView = null;

	public function new(args : Array<String>) {
		if( !args.contains("--headless") )
			view = new BotGameView();
		super(args);
	}

	function getConfig() return {
		version: "1.0",
		minPlayers : 2,
		maxPlayers : 2,
	}

	function init() : BotGameState {
		Sys.stdout().writeString('Game Starting... (headless : ${view == null})');
        Sys.stdout().flush();
		return null;
	}

	function turn(state : BotGameState) : Void {
	}

	function parseAction(action : String ) : Action {
		return Wait;
	}

	public static function main() {
		new Runner(BotGameServer, Sys.args());
	}
}