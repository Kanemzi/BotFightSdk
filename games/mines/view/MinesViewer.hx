package view;

import server.MinesState;
import server.MinesState.Robot;
import server.MinesState.Object;

import botfight.viewer.VisualEventTimeline.TimelineBuilder;
import botfight.viewer.VisualEventTimeline.LifetimeRule;
import botfight.viewer.VisualEvent;

@color(0x8b8b23)
class RobotLifetimeEvent extends StateVisualEvent<Robot> {}

@color(0x7b838b)
class ObjectLifetimeEvent extends StateVisualEvent<Object> {}

class MinesViewer extends botfight.viewer.GameViewer<MinesState> {
	function getTimelineBuilder() return new TimelineBuilder()
		.addRule(new LifetimeRule<MinesState, Robot>(
			gs -> gs.players.flatMap(p -> p.robots),
			r -> new RobotLifetimeEvent(r)
		))
		.addRule(new LifetimeRule<MinesState, Object>(
			gs -> gs.objects,
			o -> new ObjectLifetimeEvent(o)
		));
}