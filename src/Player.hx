
abstract class Player<TAction : EnumValue> {
    var history : Array<TAction>;

    public function getLastAction() : TAction {
        if( history.length == 0 ) return null;
        return history[history.length - 1];
    } 
}