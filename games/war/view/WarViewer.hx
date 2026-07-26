package view;

import server.WarState;
import botfight.viewer.VisualEventTimeline.TimelineBuilder;

import botfight.viewer.view.MatchView;

class WarViewer extends botfight.viewer.GameViewer<WarState> {
	function getTimelineBuilder() return new TimelineBuilder()
		/*.addRule(null)*/;

	function getScene() return new WarGameScene();
}