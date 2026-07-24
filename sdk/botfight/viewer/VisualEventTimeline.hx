package botfight.viewer;

import botfight.core.GameState;
import botfight.core.GameState.State;
import botfight.core.GameState.SUID;
import botfight.core.action.Action;
import botfight.core.History;

/*
	When loading a replay. Everything happening during the game 
	that should be displayed will be baked into a Timeline composed if VisualEvents

	A VisualEvent is something that makes an element visible for a certain amount of time
	on the replay viewer.
	They can be bound to a state life time (for example a unit that should be displayed unit its death).
	They are in charge of spawning/removing and updating their visual elements in the scene
*/

typedef EventId = Int;

@:allow(botfight.viewer.TimelineRule)
@:allow(botfight.viewer.TimelineBuilder)
class VisualEvent<Ts : State> {
	public var id(default, null) : EventId = -1; // event ids will be given by the TimelineBuilder
	public var start(default, null) : Float = -1;
	public var end(default, null) : Float = -1;
	public var suid(default, null) : Null<SUID>;

 	function new(?suid : SUID) {
		this.suid = suid;
	}

	public function resolveRef(turn : Int) :Ts {
		return null; // @todo implement
	}
}

class VisualEventTimeline<Ts : GameState> {
	var eventMap : Map<EventId, VisualEvent<Ts>>;
	var sortedEvents : Array<VisualEvent<Ts>>;

	public function new(events : Array<VisualEvent<Ts>>) {
		eventMap = [for (ev in events) ev.id => ev];
		sortedEvents = [for (_ => v in events) v];
		sortedEvents.sort((a, b) -> a.start > b.start ? 1 : -1);
	}
}

abstract class TimelineRule<Ts : GameState> {
	var opened : Map<String, VisualEvent<Ts>>;
	var history : History<Ts, Action>;

	public function bake(history : History<Ts, Action>) : Array<VisualEvent<Ts>>{
		this.history = history;
		var events = [];
		opened = [];

		iter(history, (t, p, n) -> {
			for (ev in eval(t, p, n)) {
				events.push(ev);
			}
		});

		var end = history.length;
		for (ev in opened) {
			ev.end = end;
			events.push(ev);
		}
		return events;
	}

	final function iter(history : History<Ts, Action>, f : (t : Int, prev : Ts, next : Ts) -> Void) : Void {
		if (history.length == 0 )
			return;

		var prev : Ts = null;
		for (i in 0...history.length + 1) { // last iteration will set next to null
			var next = history.turns[i]?.state;
			f(i, prev, next);
			prev = next;
		}
	}

	/**
		Évaluates a transition between two states and instantiate / close visual events.
		First call of eval, [prev] is null.
		Last call of eval, [next] is null.
	*/
	public function eval(turn : Int, prev : Ts, next : Ts) : Array<VisualEvent<Ts>> {
		return [];
	}

	final function openEvent(key : String, start : Float, ev : VisualEvent<Ts>) {
		if (opened.exists(key))
			throw 'Key "$key" was already used to open an event, previous event would be overriden';
		ev.start = start;
		opened.set(key, ev);
	}

	final function closeEvent(key : String, end : Float) : VisualEvent<Ts> {
		if (!opened.exists(key))
			throw 'Event of key "$key" is not open';

		var ev = opened.get(key);
		opened.remove(key);
		ev.end = hxd.Math.max(ev.end, end);
		return ev;
	}

	static inline function makeKey(ts : State, kind : String) return '$kind${ts.id}';
}

class TimelineBuilder<Ts : GameState> {
	var rules : Array<TimelineRule<Ts>>;

	public function new() {}

	public function addRule(rule : TimelineRule<Ts>) {
		(rules ??= []).push(rule);
		return this;
	}

	@:allow(botfight.viewer.GameViewer)
	function bake(history : History<Ts, Action>) : VisualEventTimeline<Ts> {
		var events = [];
		if (rules != null) {
			for (r in rules) for (e in r.bake(history)) {
				e.id = events.length;
				events.push(e);
			}
		}
		return new VisualEventTimeline(events);
	}
}