package botfight.viewer.widget;

class Button extends Widget {

	@:p public var text(default, set) : String;

	var label : h2d.Text;

	public function new(?parent) {
		super(parent);
		initComponent();
		label = new h2d.Text(hxd.res.DefaultFont.get(), this);
	}

	function set_text(t) {
		label.text = t == null ? "" : t;
		return text = t;
	}
}