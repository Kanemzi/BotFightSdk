package games.war.view;

import games.war.WarState;
import view.VisualEventTimeline.TimelineBuilder;

class WarViewer extends view.GameViewer<WarState> {
    function getTimelineBuilder() return new TimelineBuilder()
        /*.addRule(null)*/;
}