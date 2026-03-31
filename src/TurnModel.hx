import GameState;

interface TurnModel {
    public function getPlayingThisTurn<TAction : EnumValue>(players : Array<Player<TAction>>, state : GameState, turn : Int) : Array<Player<TAction>>;
}

class SequentialTurn implements TurnModel {
    public function getPlayingThisTurn<TAction : EnumValue>(players : Array<Player<TAction>>, state : GameState, turn : Int) : Array<Player<TAction>> {
        return [players[turn % players.length]];
    }
}

class SimultaneousTurn implements TurnModel {
    public function getPlayingThisTurn<TAction : EnumValue>(players : Array<Player<TAction>>, state : GameState, turn : Int) : Array<Player<TAction>> {
        return players;
    }
}