package botfight.viewer.view;

import botfight.core.GameState;
import botfight.core.History;
import botfight.core.action.Action;
import botfight.viewer.widget.Widget;
import botfight.viewer.VisualEventTimeline;
import botfight.viewer.VisualEvent.StateVisualEvent;

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

class TimelineDebug extends Widget {
	static var SRC = <timeline-debug>
	</timeline-debug>

	static inline var ROW_HEIGHT = 4;
	static inline var PX_PER_TURN = 6.;
	static inline var MIN_WIDTH = 4.;

	var canvas : h2d.Object;

	public function new(timeline : VisualEventTimeline, ?parent) {
		super(parent);
		initComponent();
		canvas = new h2d.Object(this);
		getProperties(canvas).isAbsolute = true;
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
			g.drawRect(begin * PX_PER_TURN, row * ROW_HEIGHT, w, ROW_HEIGHT - 2);
			g.endFill();
		}
	}
}

class TimelineDebugView<Ts : GameState> extends View {
	static var SRC = <timeline-debug-view>
		<flow class="head">
			<text text={'Timeline viewer'} />
			<button id="leave-btn">
				<text text={'X'} />
			</button>
		</flow>
		<timeline-debug(timeline) />
	</timeline-debug-view>

	public function new(timeline : VisualEventTimeline) {
		super();
		initComponent();

		leaveBtn.onClick = _ -> ui.pop(); // @todo might create a common "closable view" with ReplayView
	}
}