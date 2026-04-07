package;

import massive.munit.util.Timer;
import massive.munit.Assert;
import massive.munit.async.AsyncFactory;

import core.GameServer;
import core.action.ActionCollector;

enum TestAction {
	Wait;
	Move(x : Int, y : Int, kind : Word, ?msg : String);
	Say(x : Int, y : Int, msg : String);
	End;
}

class TestActionParser extends ActionParser<TestAction> {
	public function new() {}
}

class ActionCollectorTest
{
	static inline final TIMEOUT = 1.0;
	var parser : TestActionParser;

	@BeforeClass
	public function setup() {
		parser = new TestActionParser();
	}
	
	@Test
	public function testParseActions() {
		inline function _(s, v) Assert.areEqual(parser.parseAction(s), v);
		_("MOVE 1 1 Unit Hello World !", Move(1, 1, "Unit", "Hello World !"));
		_("MOVE 1 1 Unit ", Move(1, 1, "Unit", null));
		_("MOVE 1 1 Unit", Move(1, 1, "Unit", null));
		_("SAY 1 1 Hello World !", Say(1, 1, "Hello World !"));
		_("SAY 1 1", null);
	}

	@Test
	public function test2Waits1Move() {
		var player = new Player(0, new TestPlayerIO([
			"WAIT",
			"WAIT",
			"MOVE 1 1 Run",
			"WAIT",
		]));
		
		var collector = Sequence([
			Fixed(2, t -> t == Wait),
			Fixed(1, t -> t.match(Move(_, _)))
		]);

		var res = player.collectActions(collector, TIMEOUT, parser);
		Assert.areEqual(res.actions, [Wait, Wait, Move(1, 1, "Run")]);
	}
}