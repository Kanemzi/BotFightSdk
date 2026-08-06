package cogpit.client.view;

import cogpit.core.GameState;
import cogpit.client.widget.Widget;
import cogpit.client.VisualEventTimeline;
import cogpit.client.VisualEvent;
import cogpit.client.VisualEvent.StateVisualEvent;

class EventDisplay {
	public static function name(ev : VisualEvent) : String
        return Type.getClassName(Type.getClass(ev)).split(".").pop();

	// @todo fallback on parent class color
    public static function color(ev : VisualEvent) : Int {
        var meta = haxe.rtti.Meta.getType(Type.getClass(ev));
        var c : Array<Dynamic> = meta?.color;
        return (c != null && c.length > 0) ? c[0] : 0xffffff;
    }
}

// @todo clean

class TimelineDebug extends Widget {
	static var SRC = <timeline-debug class="closable-view">
	</timeline-debug>

	static inline var ROW_HEIGHT = 4;
	static inline var PX_PER_TURN = 6.;
	static inline var MIN_WIDTH = 4.;

	static inline var ZOOM_MIN = 0.4;
	static inline var ZOOM_MAX = 6.;
	static inline var ZOOM_STEP = 1.5;

	var canvas : h2d.Object;
	var zoom : Float = 1.;
	var dragOriginX : Float;
	var dragOriginY : Float;
	var tooltip : h2d.Text;

	public function new(timeline : VisualEventTimeline, ?parent) {
		super(parent);
		initComponent();
		canvas = new h2d.Object(this);
		getProperties(canvas).isAbsolute = true;

		interactive.onWheel = onZoom;

		tooltip = new h2d.Text(hxd.res.DefaultFont.get(), this);
		getProperties(tooltip).isAbsolute = true;
		tooltip.textColor = 0xffffff;
		tooltip.dropShadow = { dx : 1, dy : 1, color : 0x000000, alpha : 1 };
		tooltip.visible = false;

		drawTimeline(timeline);
	}

	public function drawTimeline(timeline : VisualEventTimeline) {
		canvas.removeChildren();

		var events = @:privateAccess timeline.sortedEvents;
		if (events.length == 0) return;

		var font = hxd.res.DefaultFont.get();

		for (row => ev in events) {
			var begin = ev.begin < 0 ? 0. : ev.begin;
			var end = ev.end < 0 ? begin : ev.end;
			var w = hxd.Math.max(MIN_WIDTH, (end - begin) * PX_PER_TURN);

			var g = new h2d.Graphics(canvas);
			g.beginFill(EventDisplay.color(ev));
			g.drawRect(begin * PX_PER_TURN, row * ROW_HEIGHT, w, ROW_HEIGHT / 2);
			g.endFill();

			var itv = new h2d.Interactive(w, ROW_HEIGHT / 2, g);
			itv.x = begin * PX_PER_TURN;
			itv.y = row * ROW_HEIGHT;
			itv.propagateEvents = true; // let push/move fall through to the underlying drag/zoom interactive
			itv.onOver = e -> showTooltip(ev, itv, e);
			itv.onMove = e -> showTooltip(ev, itv, e);
			itv.onOut = e -> hideTooltip();
		}
	}

	function showTooltip(ev : VisualEvent, itv : h2d.Interactive, e : hxd.Event) {
		var label = EventDisplay.name(ev);
		var suid = Std.downcast(ev, StateVisualEvent);
		if (suid != null) label += ' #${suid.suid}';
		tooltip.text = label;

		var p = itv.localToGlobal(new h2d.col.Point(e.relX, e.relY));
		this.globalToLocal(p);
		tooltip.x = p.x + 8;
		tooltip.y = p.y - 14;
		tooltip.visible = true;
	}

	function hideTooltip() {
		tooltip.visible = false;
	}

	function onZoom(e : hxd.Event) {
		var factor = e.wheelDelta < 0 ? ZOOM_STEP : 1 / ZOOM_STEP;
		var newZoom = hxd.Math.clamp(zoom * factor, ZOOM_MIN, ZOOM_MAX);
		if (newZoom == zoom) return;

		// keep the point under the cursor fixed while zooming
		var localX = (e.relX - canvas.x) / zoom;
		var localY = (e.relY - canvas.y) / zoom;

		zoom = newZoom;
		canvas.setScale(zoom);
		canvas.x = e.relX - localX * zoom;
		canvas.y = e.relY - localY * zoom;
	}

	override function onPush() {
		dragOriginX = canvas.x;
		dragOriginY = canvas.y;
	}

	override function onDrag(x : Float, y : Float, dx : Float, dy : Float) {
		canvas.x = dragOriginX + dx;
		canvas.y = dragOriginY + dy;
	}
}

class TimelineDebugView<Ts : GameState> extends View {
	static var SRC = <timeline-debug-view>
		<flow class="head">
			<text text={'Timeline viewer'} />
			<button id="leave-btn" text="X" />
		</flow>
		<timeline-debug(timeline) />
	</timeline-debug-view>

	var timeline : VisualEventTimeline;

	public function new(timeline : VisualEventTimeline) {
		super();
		this.timeline = timeline;
	}

	override function init() {
		initComponent();
		leaveBtn.onClick = _ -> ui.pop(); // @todo might create a common "closable view" with ReplayView
	}
}