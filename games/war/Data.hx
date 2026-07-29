private typedef Init = haxe.macro.MacroType<[cdb.Module.build("data.cdb")]>;

@:build(cdb.Macros.buildConsts("data.cdb", "constant@value"))
class Const {}

class DataExtensions {
	public static function canOrder(b : Data.Building, order : Data.OrderKind) {
		return b.orders.exists(o -> o.orderId == order);
	}
}