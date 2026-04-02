import GameState;

interface TurnModel {
    public function getPlayingThisTurn<Ta : EnumValue>(players : Array<Player<Ta>>, state : GameState, turn : Int) : Array<Player<Ta>>;
}

class SequentialTurn implements TurnModel {
    // @todo when a player is killed, another player might play twice with this strategy
    public function getPlayingThisTurn<Ta : EnumValue>(players : Array<Player<Ta>>, state : GameState, turn : Int) : Array<Player<Ta>> {
        return [players[turn % players.length]];
    }
}

class SimultaneousTurn implements TurnModel {
    public function getPlayingThisTurn<Ta : EnumValue>(players : Array<Player<Ta>>, state : GameState, turn : Int) : Array<Player<Ta>> {
        return players;
    }
}