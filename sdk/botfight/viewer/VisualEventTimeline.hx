package botfight.viewer;

import botfight.core.GameState;
import botfight.core.GameState.State;
import botfight.core.GameState.SUID;
import botfight.core.action.Action;
import botfight.core.History;
import botfight.viewer.VisualEvent.EventId;
import botfight.viewer.VisualEvent.StateVisualEvent;
import botfight.viewer.replay.StateRegistry;

/*
	When loading a replay. Everything happening during the game 
	that should be displayed will be baked into a Timeline composed if VisualEvents

	A VisualEvent is something that makes an element visible for a certain amount of time
	on the replay viewer.
	They can be bound to a state life time (for example a unit that should be displayed unit its death).
	They are in charge of spawning/removing and updating their visual elements in the scene
*/

typedef StateExtractor<Ts : GameState, T : State> = Ts -> Array<T>;

@:allow(botfight.viewer.TimelineBuilder)
class VisualEventTimeline {
	public var duration(default, null) : Float;
	var eventMap : Map<EventId, VisualEvent>;
	var sortedEvents : Array<VisualEvent>;

	function new(events : ReadOnlyArray<VisualEvent>, duration : Float) {
		this.duration = duration;
		eventMap = [for (ev in events) ev.id => ev];
		sortedEvents = [for (ev in events) ev];
		sortedEvents.sort((a, b) -> a.begin > b.begin ? 1 : -1);
	}

	var _activeEventsCache : Array<VisualEvent> = null;
	public function activeEventsAt(t : Float) : ReadOnlyArray<VisualEvent> {
		(_activeEventsCache ??= []).resize(0);
		for (ev in sortedEvents)
			if (ev.begin <= t && t <= ev.end) _activeEventsCache.push(ev);
		return _activeEventsCache;
	}
}

class TimelineBuilder<Ts : GameState> {
	var rules : Array<TimelineRule<Ts>>;

	public function new() {}

	public function addRule(rule : TimelineRule<Ts>) {
		(rules ??= []).push(rule);
		return this;
	}

	public function bake(history : History<Ts, Action>) : VisualEventTimeline {
		var ctx = new StateRegistry(history);
		var events = [];
		if (rules != null) {
			for (r in rules) for (e in r.bake(history)) {
				e.id = events.length;
				var ve = Std.downcast(e, StateVisualEvent);
				if (ve != null)
					ve.ctx = ctx.get(ve.suid); 
				events.push(e);
			}
		}

		return new VisualEventTimeline(events, history.length);
	}
}

abstract class TimelineRule<Ts : GameState> {
	var opened : Map<String, VisualEvent>;

	public function bake(history : History<Ts, Action>) : Array<VisualEvent>{
		var events = [];
		opened = [];

		iter(history, (t, p, n) -> {
			for (ev in bakeTurn(t, p, n))
				events.push(ev);
		});

		var end = history.length;
		for (ev in opened) {
			ev.end = end;
			events.push(ev);
		}
		return events;
	}

	final function iter(history : History<Ts, Action>, f : (t : Int, from : Ts, to : Ts) -> Void) : Void {
		if (history.length == 0)
			return;

		var from : Ts = null;
		for (i in 0...history.length + 1) {
			var to = history.turns[i]?.state;
			f(i - 1, from, to);
			from = to;
		}
	}

	/**
		Évaluates a transition between two states and instantiate / close visual events.
		First call of eval, [from] is null.
		Last call of eval, [to] is null.
	*/
	public function bakeTurn(turn : Int, from : Ts, to : Ts) : Array<VisualEvent> {
		return [];
	}

	final function openEvent(key : String, begin : Float, ev : VisualEvent) {
		if (opened.exists(key))
			throw 'Key "$key" was already used to open an event, previous event would be overriden';
		ev.begin = begin;
		opened.set(key, ev);
	}

	final function closeEvent(key : String, end : Float) : VisualEvent {
		if (!opened.exists(key))
			throw 'Event of key "$key" is not open';

		var ev = opened.get(key);
		opened.remove(key);
		ev.end = hxd.Math.max(ev.end, end);
		return ev;
	}
}

/**
	Helper rule that allows generating VisualEvents that represent the lifetime of specific states
*/
class LifetimeRule<Ts : GameState, T : State> extends TimelineRule<Ts> {
	var extract : StateExtractor<Ts, T>;
	var factory : T -> StateVisualEvent<T>;

	public function new(ext : StateExtractor<Ts, T>, ?f : T -> StateVisualEvent<T> ) {
		extract = gs -> gs == null ? [] : ext(gs);
		factory = f;
	}

	override function bakeTurn(turn : Int, from : Ts, to : Ts) : Array<VisualEvent> {
		final from : Array<T> = extract(from);
		final to  : Array<T> = extract(to);
		var events = [];

		for (t in to) 
			if (!from.exists(f -> f.id == t.id)) {
				var ev = factory != null ? factory(t) : new StateVisualEvent(t);
				openEvent('${t.id}', turn + 1, ev);
			}

		for (f in from)
			if (!to.exists(t -> t.id == f.id))
				events.push(closeEvent('${f.id}', turn));

		return events;
	}
}