package cogpit.client.replay;

import cogpit.client.VisualEventTimeline;
import cogpit.client.VisualEvent;
import cogpit.client.widget.*;

/**
	API to expose options for visual quality, debug, etc... 
**/

@:allow(cogpit.client.replay.GameViewport)
abstract class GameScene {
	var s2d(default, null) : h2d.Object;
	var s3d(default, null) : h3d.scene.Scene;
	var gizmos(default, null) : Gizmos;
	var gizmos2d(default, null) : Gizmos;

	public function new() {}

	function init(events : ReadOnlyArray<VisualEvent>) : Void {}

	function onEventBegin(ev : VisualEvent) : Void {}
	function onEventEnd(ev : VisualEvent) : Void {}
	function update(t : Float, events : ReadOnlyArray<VisualEvent>) : Void {}

	function onResize() : Void {}
	function onDispose() : Void {}

}

@:allow(cogpit.client.view.ReplayView)
final class GameViewport extends Widget {

	var viewport : h2d.Scene3D;
	var fpsGraph : FpsGraph;

	var eventsEnabled : Bool = true;

	final timeline : VisualEventTimeline;
	final gameScene : GameScene;
	var time : Float = 0.;
	var activeEvents : ReadOnlyArray<VisualEvent> = [];

	function new(timeline : VisualEventTimeline, gameScene : GameScene, ?parent) {
		super(parent);
		initComponent();

		this.timeline = timeline;
		this.gameScene = gameScene;

		viewport = new h2d.Scene3D(new hxd.SceneEvents(), this);
		viewport.fillWidth = viewport.fillHeight = true;
		viewport.backgroundColor = 0xFF202020;
		gameScene.s2d = viewport.s2d;
		gameScene.s3d = viewport.s3d;
		gameScene.gizmos = Gizmos.make3d(viewport.s3d, viewport.s2d);
		gameScene.gizmos2d = Gizmos.make2d(viewport.s2d);

		fpsGraph = new FpsGraph(viewport.s2d);
		fpsGraph.visible = false;

		final _onAfterReflow = viewport.onAfterReflow;
		viewport.onAfterReflow = () -> {
			_onAfterReflow();
			gameScene.onResize();
		}

		gameScene.init(@:privateAccess timeline.sortedEvents.copy());
	}

	inline function advance(dt : Float) : Void { seek(time + dt); }
	final function seek(t : Float) : Void {
		time = t;
		// @todo optimize allocations since this might be called 60 times per frame
		final events = timeline.activeEventsAt(t);
		
		for (ev in events)
			if (!activeEvents.has(ev)) gameScene.onEventBegin(ev);
		
		for (ev in activeEvents)
			if (!events.has(ev)) gameScene.onEventEnd(ev);

		activeEvents = events;
		gameScene.update(time, events);
	}

	override function sync(ctx : h2d.RenderContext) {
		// @todo find a better way to focused game scene
		if (!eventsEnabled) {
			@:privateAccess viewport.events.pendingEvents.keep(e -> !e.kind.match(EWheel | EPush));
		}
		viewport.events.checkEvents();
		fpsGraph.update(ctx.elapsedTime);
		gameScene.gizmos.refresh();
		gameScene.gizmos2d.refresh();
		super.sync(ctx);
	}

	override function onRemove() {
		super.onRemove();
		gameScene.onDispose();
	}
}