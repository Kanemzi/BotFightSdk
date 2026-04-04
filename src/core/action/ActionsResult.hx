package core.action;

import core.Player.PlayerId;
import core.Player.Status;

@:structInit @:publicFields
final class ActionsResult<Ta : Action> implements hxbit.Serializable {
	@:s var id : PlayerId;
    @:s var status : Status;
	@:s var error : Null<String>;
	
	var actions : Array<Ta>;
	var time : Int;

	public function customSerialize(ctx : hxbit.Serializer) @:privateAccess {
		ctx.addInt(actions?.length);
		for (a in actions) ctx.addDynamic(a);
	}

	public function customUnserialize(ctx : hxbit.Serializer) @:privateAccess {
		var len = ctx.getInt();
		actions = [for (_ in 0...len) ctx.getDynamic()];
	}
}