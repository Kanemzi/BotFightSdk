private typedef Init = haxe.macro.MacroType<[cdb.Module.build("data.cdb")]>;

@:build(cdb.Macros.buildConsts("data.cdb", "constant@value"))
class Const {}