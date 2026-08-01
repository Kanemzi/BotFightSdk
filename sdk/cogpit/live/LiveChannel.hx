package cogpit.live;

import sys.thread.Deque;
import cogpit.core.History;
import cogpit.core.GameState;
import cogpit.core.action.Action;

enum LiveEvent {
	MatchSlotAllocated;
	MatchSlotReady;
	GameBegin;
	GameTurn;
	GameComplete;
}

/**
	Thread safe context used for realtime communication between the game server and the client
*/
class LiveChannel {
	final queue : Deque<LiveEvent>;
	public function new() {
		queue = new Deque();
	}

	public dynamic function onGameBegin<Ts : GameState, Ta : Action>(history : History<Ts, Ta>) {}
	final public function notifyGameBegin<Ts : GameState, Ta : Action>(history : History<Ts, Ta>) {
		onGameBegin(history);
		notify(GameBegin);
	}
	final public function notify(e : LiveEvent) queue.add(e);
	final public function poll() : Null<LiveEvent> return queue.pop(false);
}