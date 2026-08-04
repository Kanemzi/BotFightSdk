package client;

import cogpit.client.VisualEventTimeline.TimelineBuilder;
import cogpit.client.view.MatchView;
import server.state.WarState;

class WarClient extends cogpit.client.GameClient<WarState> {
	function getTimelineBuilder() return new TimelineBuilder()
		/*.addRule(null)*/;

	function getScene() return new WarGameScene();
}