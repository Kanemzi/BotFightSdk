package war.view;

import war.WarState;
import botfight.viewer.VisualEventTimeline.TimelineBuilder;

import botfight.viewer.view.MatchView;

class WarViewer extends botfight.viewer.GameViewer<WarState> {
	function getTimelineBuilder() return new TimelineBuilder()
		/*.addRule(null)*/;
}