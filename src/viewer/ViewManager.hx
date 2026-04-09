package view;

class ViewManager extends h2d.Flow {
	public var s2d(default,null) : h2d.Scene;
	public var style(default, null) : h2d.domkit.Style;

	var stack : Array<View>;
	public var current(get, never) : View;
	function get_current() return stack?.length == 0 ? null : stack[stack.length - 1]; 

	public function new(s2d : h2d.Scene) {
		super();
		stack = [];
		
		this.s2d = s2d;
		dom = domkit.Properties.create("flow", this);
		dom.addClass("root");
		fillWidth = fillHeight = true;
		
		initStyle();

		s2d.addChild(this);
	}

	function initStyle() {
		style = new h2d.domkit.Style();
		style.useSmartCache = true;
		//style.addObject(this);
		style.loadComponents("style");
		#if hl
		if (hl.Api.hasDebugger())
			style.allowInspect = true;
		#end
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

	public function pop() {
		var last = stack.pop();
		if (last == null) return;
		last.onClose();
		style.removeObject(last);
		last.remove();

		current?.onResume();
		refreshViews();
	}

	public function replace(view : View) {
		while (!stack.empty()) {
			var last = stack.pop();
			last.onClose();
			last.remove();
		}
		push(view);
		refreshViews();
	}

	public function refreshViews() {
		for (v in stack)
			v.visible = v == current;
	}

	public function update(dt : Float) {
		current?.update(dt);
	}
}