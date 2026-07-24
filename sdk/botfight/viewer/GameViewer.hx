package botfight.viewer;

import botfight.core.GameState;
import botfight.core.History;
import botfight.core.action.Action;
import botfight.viewer.VisualEventTimeline.TimelineBuilder;

/*
Design : 
- A viewer takes a Runner output (directly or from a saved file for replay mode)
- Runner outputs all the informations about the games that have been played in a batch (Tournament, BO7, ...)
- It has a main menu to visualize the games outcomes / global infos (list or tournament tree), select one of them and replay it.
	- Ideally it has a spectator mode that plays all the games in a row, or a chosen subset
- Allows other features like fast GameState gen debugging.
*/

abstract class GameViewer<Ts : GameState> extends hxd.App {
	var match : Match<Ts, Action>;
	var ui : ViewManager;

	public function new(match : Match<Ts, Action>) {
		super();
		
		hxd.Res.initLocal();
		hxd.res.Resource.LIVE_UPDATE = #if hl hl.Api.hasDebugger() #else false #end;

		this.match = match;
	}

	override function init() {
		super.init();
		ui = new ViewManager(s2d);
		ui.push(new botfight.viewer.view.MatchView(match, getTimelineBuilder()));
	}
	
	abstract function getTimelineBuilder() : TimelineBuilder<Ts>;

	function playGame(history : History<Ts, Action>) {
		final builder = getTimelineBuilder();
		if (builder == null)
			throw 'No TimelineBuilder provided to the viewer';
		final timeline = builder.bake(history);
		trace(timeline);
	}

	override function update(dt : Float) {
		ui.update(dt);
	}
}