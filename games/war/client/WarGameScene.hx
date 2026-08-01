package client;

import cogpit.client.replay.GameScene;
import cogpit.client.VisualEvent;
import cogpit.client.VisualEvent.EventId;

class WarGameScene extends GameScene {
	override function init(events : ReadOnlyArray<VisualEvent>) {}

	override function onEventBegin(ev : VisualEvent) {}
	override function onEventEnd(ev : VisualEvent) {}

	override function update(t : Float, events : ReadOnlyArray<VisualEvent>) {}

	override function onResize() {}
}