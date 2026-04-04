package view;

import core.GameState;

/*
    When loading a replay. Everything happening during the game 
    that should be displayed will be baked into a Timeline composed if VisualEvents

    A VisualEvent is something that makes an element visible for a certain amount of time
    on the replay viewer.
    They can be bound to a state life time (for example a unit that should be displayed unit its death).
    They are in charge of spawning/removing and updating their visual elements in the scene
*/

typedef EventId = Int;

class VisualEvent<Ts : State> {
    var id : EventId;
    var start : Int;
    var end : Int;
    var suid : Int;
}

abstract class TimelineRule<Ts : GameState> {
    public function bake(history : )

    public function 
}

class VisualEventTimeline {
    var events : Map<EventId, VisualEvent>;

}