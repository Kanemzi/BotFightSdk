package botfight.viewer.view;

import botfight.core.GameState;
import botfight.core.History;
import botfight.core.History.HistoryHeader;
import botfight.core.action.Action;
import botfight.viewer.replay.GameScene;

// @todo clean
class ControlBar extends h2d.Flow implements h2d.domkit.Object {
	static var SRC = <control-bar>
		<flow class="controls">
			<button id="prev-turn-btn" text="p" />
			<button id="play-btn" text="Play" />
			<button id="next-turn-btn" text="n" />
			<text id="turn" text={'0/${hxd.Math.floor(duration)}'} />
		</flow>
		<widget class="track" id>
			<flow class="fill" id="track-fill" />
			<flow class="handle" id="track-handle" />
		</widget>
	</control-bar>

	final duration : Float;

	var time(default, set) : Float = 0.;
	var playing(default, set) : Bool = false;
	var speed : Float = 2;

	public dynamic function onSeek(t : Float) {}

	function new(duration : Float, ?parent) {
		this.duration = duration;
		super(parent);
		initComponent();
		
		playBtn.onClick = r -> if(!r) playing = !playing;
		
		// @todo clean
		track.onPush = () -> {
			var scene = track.getScene();
			var p = track.globalToLocal(new h2d.col.Point(scene.mouseX, scene.mouseY));
			playing = false;
			var t = hxd.Math.clamp(p.x / track.outerWidth, 0., 1.) * duration;
			time = t;
		}
		track.onDrag = (x, y, dx, dy) -> {
			var t = hxd.Math.clamp(x / track.outerWidth, 0., 1.) * duration;
			if (!hxd.Key.isDown(hxd.Key.SHIFT))
				t = hxd.Math.round(t);
			time = t;
		}

		track.getProperties(trackFill).isAbsolute = true;
        track.getProperties(trackHandle).isAbsolute = true;
		track.enableInteractive = true;

		final _onAfterReflow = track.onAfterReflow;
        track.onAfterReflow = () -> {
			_onAfterReflow();
			redraw();
		}
	}

	function set_playing(v : Bool) {
		playing = v;
		playBtn.text = playing ? "Pause" : "Play";
		return playing;
	}

	function set_time(t : Float) {
		if (t == time) return t;
		time = hxd.Math.clamp(t, 0., duration);
		redraw();
		onSeek(time);
		return time;
	}

	function redraw() {
		turn.text = '${hxd.Math.floor(time)}/${hxd.Math.floor(duration)}';
		var ratio = hxd.Math.clamp(time / duration, 0., 1.);
        trackFill.minWidth = Std.int(ratio * track.outerWidth);
        trackHandle.x = ratio * track.outerWidth - trackHandle.outerWidth / 2;
	}

	public function update(dt : Float) {
		if (!playing) return;

		time += dt * speed;

		if (time >= duration) {
			playing = false;
			time = duration;
		}
	}
}

class ReplayView<Ts : GameState> extends View {
	static var SRC = <replay-view>
		<flow class="head">
			<text text={'Game - ${info.seed}'} />
			<button id="leave-btn" text="X" />
		</flow>
		<game-viewport(timeline, view) id="viewport" />
		<control-bar(timeline.duration) id="control-bar" />
		</replay-view>
		
	public function new(info : HistoryHeader, timeline : VisualEventTimeline, gscFactory : Void -> GameScene) {
		super();

		var view = gscFactory();
		initComponent();

		controlBar.onSeek = t -> viewport.seek(t);
		leaveBtn.onClick = _ -> {
			@:privateAccess hxd.Window.getInstance()?.mouseMode = Absolute;
			ui.pop();
		}
	}

	override function update(dt : Float) {
		controlBar.update(dt);
	}
}

/**
	Design for replay mode :
	
	Input : a timeline of abstract events. Events are linked to States

	The replay holds a heaps scene with visual objects that should be updated depending
	on events or related states.
	
	It can update the scene from a state of a specific turn, to the immediate next or 
	previous step (or interpolate between them).
	



*/