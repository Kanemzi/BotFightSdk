package view;

import core.GameState;
import core.GameState.State;
import core.History;

/*
	When loading a replay. Everything happening during the game 
	that should be displayed will be baked into a Timeline composed if VisualEvents

	A VisualEvent is something that makes an element visible for a certain amount of time
	on the replay viewer.
	They can be bound to a state life time (for example a unit that should be displayed unit its death).
	They are in charge of spawning/removing and updating their visual elements in the scene
*/

typedef EventId = Int;

@:publicFields @:structInit
class VisualEvent<Ts : State> {
	var id : EventId;
	var start : Int;
	var end : Int;
	var suid : Int;
	var data : Dynamic;
}

class VisualEventTimeline<Ts : GameState> {
	var eventMap : Map<EventId, VisualEvent<Ts>>;
	var sortedEvents : Array<VisualEvent<Ts>>;

	public function new(events : Array<VisualEvent<Ts>>) {
		eventMap = [for (ev in events) ev.id => ev];
		sortedEvents = [for (_ => v in events) v];
		sortedEvents.sort((a, b) -> a.start - b.start);
	}
}

abstract class TimelineRule<Ts : GameState> {
	var opened : Map<String, VisualEvent<Ts>>;
	var history : History<Ts, EnumValue>;

	public function bake(history : History<Ts, EnumValue>) : Array<VisualEvent<Ts>>{
		this.history = history;
		var events = [];
		opened = [];

		iter(history, (t, p, n) -> {
			for (ev in pass(t, p, n)) {
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

	public function pass(turn : Int, prev : Ts, next : Ts) : Array<VisualEvent<Ts>> {
		return [];
	}

	
	final function iter(history : History<Ts, EnumValue>, f : (t : Int, prev : Ts, next : Ts) -> Void) : Void {
		if (history.length == 0 ) {
			return;
		}/*
		f(0, history);
		for( )*/
	}

	final function openEvent(key : String, start : Int, ?suid : Int, ?data : Dynamic) {
		if (opened.exists(key))
			throw 'Key "$key" was already used to open an event, previous event would be overriden';
		opened.set(key, makeEvent(start, start, suid, data));
	}

	final function closeEvent(key : String, end : Int) {
		if (!opened.exists(key))
			throw 'Event of key "$key" is not open';

		var ev = opened.get(key);
		opened.remove(key);
		ev.end = hxd.Math.imax(ev.end, end);
		return ev;
	}

	final function makeEvent(start : Int, end : Int, ?suid : Int, ?data : Dynamic) : VisualEvent<Ts> return {
		id : -1,
		start : start,
		end : end,
		suid : suid ?? history.getStateUID(), // bind event to GameState by default
		data : data,
	}

	static inline function makeKey(ts : State, kind : String) return '$kind${ts.__uid}';
}

class TimelineBuilder<Ts : GameState> {
	var rules : Array<TimelineRule<Ts>>;

	public function new() {}

	public function addRule(rule : TimelineRule<Ts>) {
		(rules ??= []).push(rule);
		return this;
	}

	@:allow(view.GameViewer)
	function bake(history : History<Ts, EnumValue>) : VisualEventTimeline<Ts> {
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