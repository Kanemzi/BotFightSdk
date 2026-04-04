package bots;

class ExampleBot {

	public static inline function getName() return "Michel~" + Std.random(10000);
	
	static final stdin = Sys.stdin();
	static final stdout = Sys.stdout();

	public static function main() {
		final args = Sys.args();
		if (args.indexOf("--config") != -1) {
			stdout.writeString('${getName()}\n');
			return;
		}

		while (true) loop();
	}

	static function loop() {
		var me = stdin.readLine();
		var o = stdin.readLine();
		Sys.stderr().writeString('me : $me, o : $o\n');
		Sys.sleep(1.0/*Std.random(500) / 1000.*/);
		var action = Std.random(100) < 50 ? "WAIT" : "MOVE 2 1";
		stdout.writeString('$action\n');
	}
}