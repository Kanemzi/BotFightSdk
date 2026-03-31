abstract class GameState implements hxbit.Serializable {
	abstract function serializeForPlayer<TAction :EnumValue>(player : Player<TAction>) : String;
}