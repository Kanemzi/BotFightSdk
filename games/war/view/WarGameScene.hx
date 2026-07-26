package view;

import botfight.viewer.replay.GameScene;
import botfight.viewer.VisualEvent;
import botfight.viewer.VisualEvent.EventId;

class WarGameScene extends GameScene {
	override function init(events : ReadOnlyArray<VisualEvent>) {}

	override function onEventBegin(ev : VisualEvent) {}
	override function onEventEnd(ev : VisualEvent) {}

	override function update(t : Float, events : ReadOnlyArray<VisualEvent>) {}

	override function onResize() {}
}