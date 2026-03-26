class ExampleBot {

    public static function getConfig() return {
        name : "Michel"
    }

    public static function main() {
        Sys.stdout().writeString(haxe.Json.stringify(getConfig()));
        Sys.stdout().flush();
    }
}