package viewer;

@:uiRootComponent
@:allow(viewer.ViewManager)
class View extends h2d.Flow implements h2d.domkit.Object {
	
	public var ui(default, null) : ViewManager;

	public function new() {
		super(null);
		initComponent();
		fillWidth = fillHeight = true;
	}
	
	function onOpen() {}
	function onClose() {}

	function onPause() {}
	function onResume() {}

	function update(dt : Float) {}
}