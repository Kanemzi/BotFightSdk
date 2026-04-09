package view;

import core.GameState;

interface EventView<Ts : State> {
    function update(prev : Ts, next : Ts, v : Float) : Void;
    function begin() : Void;
    function end() : Void;
}

abstract class StateView<Ts : State> implements EventView<Ts> {
    // @todo generated based on GameState resolver and create/removal of states
}