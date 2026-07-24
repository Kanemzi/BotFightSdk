package view;

import server.MinesState;

import botfight.viewer.VisualEventTimeline.TimelineBuilder;

class MinesViewer extends botfight.viewer.GameViewer<MinesState> {
	function getTimelineBuilder() return new TimelineBuilder();
}