package view;

import server.MinesState;
import server.MinesState.Robot;
import server.MinesState.Object;

import botfight.viewer.VisualEventTimeline.TimelineBuilder;
import botfight.viewer.VisualEventTimeline.LifetimeRule;
import botfight.viewer.VisualEvent;

@color(0x8b8b23)
class RobotLifetimeEvent extends StateVisualEvent<Robot> {
	public var team(default, null) : Int;

	public function new(r : Robot, team : Int) {
		super(r);
		this.team = team;
	}
}

@color(0x7b838b)
class ObjectLifetimeEvent extends StateVisualEvent<Object> {}

class MinesViewer extends botfight.viewer.GameViewer<MinesState> {
	function robotsTimelineRule(pid : Int) {
		return new LifetimeRule<MinesState, Robot>(
			gs -> gs.players[pid].robots,
			r -> new RobotLifetimeEvent(r, pid)
		);
	}

	function getTimelineBuilder() return new TimelineBuilder()
		.addRule(robotsTimelineRule(0))
		.addRule(robotsTimelineRule(1))
		.addRule(new LifetimeRule<MinesState, Object>(
			gs -> gs.objects,
			o -> new ObjectLifetimeEvent(o)
		));
	
	function getScene() return new MinesGameScene();
}