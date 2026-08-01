package cogpit.client;

import cogpit.live.LiveChannel.LiveEvent;

@:allow(cogpit.client.ViewManager)
@:uiRootComponent
@:uiInitFunction(init)
abstract class View extends h2d.Flow implements h2d.domkit.Object {
	
	public var ui(default, null) : ViewManager;

	public function new() {
		super(null);
		fillWidth = fillHeight = true;
	}
	
	function init() {
		initComponent();
	}

	function onOpen() {}
	function onClose() {}

	function onPause() {}
	function onResume() {}

	function onLiveEvent(ev : LiveEvent) {}
	function update(dt : Float) {}

	function rebuild() {
		removeChildren();
		init();
	}
}