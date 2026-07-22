package games.war.view;

import games.war.WarState;
import viewer.VisualEventTimeline.TimelineBuilder;

import viewer.view.MatchView;

class WarViewer extends viewer.GameViewer<WarState> {
	function getTimelineBuilder() return new TimelineBuilder()
		/*.addRule(null)*/;
}