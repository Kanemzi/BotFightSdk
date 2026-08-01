package cogpit.client.widget;

import cogpit.client.ViewManager;
import cogpit.client.View;

class Widget extends h2d.Flow implements h2d.domkit.Object {
	@:p public var enable(default, set) : Bool = true;

	var ui(get,never) : ViewManager;
	var view(get, never) : View;

	public dynamic function onClick(right : Bool) {}
	public dynamic function onPush() {}
	public dynamic function onRelease() {}
	public dynamic function onOver() {}
	public dynamic function onOut() {}
	public dynamic function onDrag(x : Float, y : Float, dx : Float, dy : Float) {}

	public function new(?parent) {
		super(parent);
		initComponent();
		initInteractive();
	}

	function initInteractive() {
		if (enableInteractive) return;
		enableInteractive = true;

		interactive.enableRightButton = true;

		interactive.onClick = e -> {
			if (!enable || e.button > 1) return;
			onClick(e.button == 1);
		}

		interactive.onPush = e -> {
			if (!enable || e.button != 0) return;
			dom?.active = true;
			
			final sx = e.relX;
			final sy = e.relY;
			interactive.startCapture( se -> {
				switch (se.kind) {
					case ERelease: interactive.stopCapture();
					case EMove:
						final dx = se.relX - sx;
						final dy = se.relY - sy;
						onDrag(se.relX, se.relY, dx, dy);
					default:
				}
			});

			onPush();
		}

		interactive.onRelease = e -> {
			if (!enable || e.button != 0) return;
			dom?.active = false;
			onRelease();
		}

		interactive.onOver = e -> {
			if (!enable) return;
			dom?.hover = true;
			onOver();
		}

		interactive.onOut = e -> {
			if (!enable) return;
			dom?.hover = false;
			onOut();
		}
	}

	function set_enable(b) {
		if (dom != null) {
			if (!b)
				dom.hover = dom.active = false;
			dom.toggleClass("disabled", !b);
		}
		return enable = b;
	}

	inline function get_ui() return view.ui;
	public function get_view() {
		var p = parent;
		while (p != null) {
			var w = Std.downcast(p, View);
			if (w != null) return w;
			p = p.parent;
		}
		return null;
	}
}