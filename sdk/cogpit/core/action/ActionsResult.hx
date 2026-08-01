package cogpit.core.action;

import cogpit.core.Player.PlayerId;
import cogpit.core.Player.Status;
import cogpit.core.GameSimulation;

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

	public static function toPlayersActions<Ta : Action>(results : ReadOnlyArray<ActionsResult<Ta>>) : PlayersActions<Ta> {
		final result = i -> results.find(r -> r.pid == i);
		var actions = results.map(r -> { pid : r.pid, actions : r.actions });
		actions.sort((a, b) -> {
			final ae = a.actions.empty(), be = b.actions.empty();
			return if (ae != be) ae ? 1 : -1
				else if (ae) 0
				else result(a.pid).time > result(b.pid).time ? 1 : -1;
		});
		return actions;
	}
}