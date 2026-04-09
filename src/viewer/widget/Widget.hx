package view.widget;

import view.ViewManager;
import view.View;

class Widget extends h2d.Flow implements h2d.domkit.Object {

	var ui(get,never) : ViewManager;
	var view(get, never) : View;

	public function new(?parent) {
		super(parent);
		initComponent();
	}

	inline function get_ui() return view.ui;
	public function get_view() {
		var p = parent;
		while( p != null ) {
			var w = Std.downcast(p, View);
			if( w != null ) return w;
			p = p.parent;
		}
		return null;
	}
}