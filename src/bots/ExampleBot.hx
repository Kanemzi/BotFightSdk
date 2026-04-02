import sys.thread.Thread;

class ExampleBot {

    public static function getConfig() return {
        name : "Michel~" + Std.random(10000)
    }

    public static function main() {
        final stdin = Sys.stdin();
        final stdout = Sys.stdout();

        stdout.writeString('${getConfig().name}\n');
        while (true) {
            var me = stdin.readLine();
            var o = stdin.readLine();
            Sys.stderr().writeString('me : $me, o : $o\n');
            Sys.sleep(Std.random(500) / 1000.);
            var action = Std.random(100) < 50 ? "WAIT" : "MOVE 2 1";
            stdout.writeString('$action\n');
        }
    }
}