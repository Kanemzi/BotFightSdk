package botfight.viewer;

class ViewManager extends h2d.Flow {
	public var s2d(default,null) : h2d.Scene;
	public var style(default, null) : h2d.domkit.Style;

	var stack : Array<View>;
	public var current(get, never) : View;
	function get_current() return stack?.length == 0 ? null : stack[stack.length - 1]; 

	public function new(s2d : h2d.Scene) {
		super();
		stack = [];

		// @todo ViewManager should have a generic and global way of handling tooltips

		this.s2d = s2d;
		dom = domkit.Properties.create("flow", this);
		dom.addClass("root");
		fillWidth = fillHeight = true;
		
		initStyle();

		s2d.addChild(this);
	}

	function initStyle() {
		final loader = hxd.res.Loader.currentInstance;
		hxd.res.Loader.currentInstance = Res.loader;
		style = new h2d.domkit.Style();
		style.useSmartCache = true;
		style.loadComponents("style");
		#if hl
		//if (hl.Api.hasDebugger())
		//	style.allowInspect = true;
		#end
		hxd.res.Loader.currentInstance = loader;
	}

	public function push(view : View) {
		current?.onPause();
		stack.push(view);
		addChild(view);
		style.addObject(view);
		view.ui = this;
		view.onOpen();
		refreshViews();
	}

	function _pop() {
		var last = stack.pop();
		if (last == null) return;
		last.onClose();
		style.removeObject(last);
		last.remove();
	}

	public function pop() {
		_pop();
		current?.onResume();
		refreshViews();
	}

	public function replace(view : View) {
		while (!stack.empty()) _pop();
		push(view);
		refreshViews();
	}

	public function refreshViews() {
		for (v in stack)
			v.visible = v == current;
	}

	public function update(dt : Float) {
		style.sync(dt);
		current?.update(dt);
	}
}