package games.mines.view;

import viewer.VisualEventTimeline.TimelineBuilder;

class MinesViewer extends viewer.GameViewer<MinesState> {
	function getTimelineBuilder() return new TimelineBuilder();
}