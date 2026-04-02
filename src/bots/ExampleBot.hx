class ExampleBot {

    public static function getConfig() return {
        name : "Michel"
    }

    public static function main() {
        //trace("BONJOUR");
        var sin = Sys.stdin();
        var sout = Sys.stdout();

        sout.writeString('${getConfig().name}\n');
        
        //trace("test");
        while (true) {
            var me = sin.readLine();
            var o = sin.readLine();
            Sys.stderr().writeString('me : $me, o : $o\n');
            var action = Std.random(100) < 50 ? "WAIT" : "MOVE 2 1";
            sout.writeString('$action\n');
        }
    }
}