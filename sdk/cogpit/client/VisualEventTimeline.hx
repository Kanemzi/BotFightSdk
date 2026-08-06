package cogpit.client;

import cogpit.client.VisualEvent.EventId;
import cogpit.client.VisualEvent.StateVisualEvent;
import cogpit.client.replay.StateRegistry;
import cogpit.core.GameServer.ServerLog;
import cogpit.core.GameState.State;
import cogpit.core.GameState;
import cogpit.core.History;
import cogpit.core.Player.PlayerId;
import cogpit.core.Player.Status;
import cogpit.core.action.Action;
import haxe.ds.ReadOnlyArray;

/*
	When loading a replay. Everything happening during the game 
	that should be displayed will be baked into a Timeline composed if VisualEvents

	A VisualEvent is something that makes an element visible for a certain amount of time
	on the replay viewer.
	They can be bound to a state life time (for example a unit that should be displayed unit its death).
	They are in charge of spawning/removing and updating their visual elements in the scene
*/

typedef StateExtractor<Ts : GameState, T : State> = Ts -> Array<T>;

enum PlayerLogKind { Error; Action; Debug; }
typedef PlayerLog = { k : PlayerLogKind, id : PlayerId, ?st : Status, msg : String }

enum TimelineLog {
	Timeline(?msg : String);
	GameServer(log : ServerLog);
	Player(log : PlayerLog);
}

typedef TurnLogs = ReadOnlyArray<TimelineLog>;

@:allow(cogpit.client.TimelineBuilder)
class VisualEventTimeline {
	public var duration(default, null) : Float;
	public var logs(default, null) : ReadOnlyArray<TurnLogs>;
	var eventMap : Map<EventId, VisualEvent>;
	var sortedEvents : ReadOnlyArray<VisualEvent>;

	function new(events : ReadOnlyArray<VisualEvent>, logs : ReadOnlyArray<TurnLogs>, duration : Float) {
		this.duration = duration;
		this.logs = logs;
		eventMap = [for (ev in events) ev.id => ev];
		final sorted = [for (ev in events) ev];
		sorted.sort((a, b) -> a.begin > b.begin ? 1 : -1);
		sortedEvents = sorted;
	}

	public function activeEventsAt(t : Float) : ReadOnlyArray<VisualEvent> {
		return sortedEvents.filter(ev -> ev.begin <= t && t <= ev.end);
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

		final logs : Array<TurnLogs> = [];
		final headerBar = "".rpad("_", 40);
		for (i in 0...history.length) {
			final turnLogs : Array<TimelineLog> = [];
			final turn = history.turns[i];
			final turnName = i == 0 ? 'Initialization' : 'Turn $i';
			turnLogs.push(Timeline('$headerBar $turnName $headerBar'));

			var acts = turn.actions.copy();
			for (ar in acts.ssort(a -> a.pid)) {
				final playerLogs : Array<PlayerLog> = [];

				if (ar.error != null)
					playerLogs.push({k : Error, id : ar.pid, st : ar.status, msg : ar.error });

				for (a in ar.actions)
					playerLogs.push({k : Action, id : ar.pid, msg : ActionParser.toString(a)});
				
				for (l in ar.logs)
					playerLogs.push({k : Debug, id : ar.pid, msg : l});

				if (!playerLogs.empty()) {
					turnLogs.push(Timeline());
					turnLogs.push(Timeline('[Player ${ar.pid}]')); // @todo find a way to access playerInfos to display name
					playerLogs.iter(l -> turnLogs.push(Player(l)));
				}
			}

			turnLogs.push(Timeline());
			turnLogs.push(Timeline('[Server]'));
			turn.serverLogs.iter(l -> turnLogs.push(GameServer(l)));
			logs.push(turnLogs);
		}

		return new VisualEventTimeline(events, logs, history.length - 1);
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