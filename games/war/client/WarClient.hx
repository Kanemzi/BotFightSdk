package client;

import server.WarState;
import cogpit.client.VisualEventTimeline.TimelineBuilder;

import cogpit.client.view.MatchView;

class WarClient extends cogpit.client.GameClient<WarState> {
	function getTimelineBuilder() return new TimelineBuilder()
		/*.addRule(null)*/;

	function getScene() return new WarGameScene();
}