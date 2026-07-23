package core.action;

import core.Player.PlayerId;
import core.Player.Status;

@:structInit @:publicFields
final class ActionsResult<Ta : Action> implements hxbit.Serializable {
	@:s var pid : PlayerId;
	@:s var status : Status;
	@:s var error : Null<String>;
	@:s var logs : Array<String>;
	@:s var time : Float;
	
	var actions : Array<Ta>;

	public function customSerialize(ctx : hxbit.Serializer) @:privateAccess {
		ctx.addInt(actions?.length);
		for (a in actions) ctx.addDynamic(a);
	}

	public function customUnserialize(ctx : hxbit.Serializer) @:privateAccess {
		var len = ctx.getInt();
		actions = [for (_ in 0...len) ctx.getDynamic()];
	}
}