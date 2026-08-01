package cogpit.client;

import cogpit.core.GameState;
import cogpit.core.History;
import cogpit.core.action.Action;
import cogpit.client.VisualEventTimeline.TimelineBuilder;
import cogpit.client.replay.GameScene;
import cogpit.live.LiveChannel;
import cogpit.live.MatchHandle;

/*
Design : 
- A viewer takes a Runner output (directly or from a saved file for replay mode)
- Runner outputs all the informations about the games that have been played in a batch (Tournament, BO7, ...)
- It has a main menu to visualize the games outcomes / global infos (list or tournament tree), select one of them and replay it.
	- Ideally it has a spectator mode that plays all the games in a row, or a chosen subset
- Allows other features like fast GameState gen debugging.
*/

abstract class GameClient<Ts : GameState> extends hxd.App {
	var match : MatchHandle<Ts, Action>;
	var ui : ViewManager;
	var live : Null<LiveChannel>;

	public function new(match : MatchHandle<Ts, Action>, ?live: LiveChannel) {
		super();
		cogpit.Res.init();
		hxd.res.Resource.LIVE_UPDATE = #if hl hl.Api.hasDebugger() #else false #end;

		this.match = match;
		this.live = live;
	}

	override function init() {
		super.init();
		ui = new ViewManager(s2d);
		ui.push(new cogpit.client.view.MatchView(match, getTimelineBuilder(), getScene));
	}
	
	abstract function getTimelineBuilder() : TimelineBuilder<Ts>;
	abstract function getScene() : GameScene;

	function playGame(history : History<Ts, Action>) {
		final builder = getTimelineBuilder();
		if (builder == null)
			throw 'No TimelineBuilder provided to the viewer';
		final timeline = builder.bake(history);
		trace(timeline);
	}

	override function update(dt : Float) {
		if (live != null) {
			var ev : LiveEvent = null;
			while ((ev = live.poll()) != null)
				ui.onLiveEvent(ev);
		}

		ui.update(dt);
	}
}