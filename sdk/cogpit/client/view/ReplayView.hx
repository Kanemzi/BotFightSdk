package cogpit.client.view;

import cogpit.core.GameState;
import cogpit.core.History.HistoryHeader;
import cogpit.core.GameServer.LogSeverity;
import cogpit.core.GameServer.ServerLog;
import cogpit.client.replay.GameScene;

// @todo clean
class ControlBar extends h2d.Flow implements h2d.domkit.Object {
	static var SRC = <control-bar>
		<flow class="controls">
			<button id="prev-turn-btn" text="p" />
			<button id="play-btn" text="Play" />
			<button id="next-turn-btn" text="n" />
			<button id="fps-btn" text="FPS" />
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

	// @todo find a more generic way to handle control bar controls
	public dynamic function onToggleFps() {}

	function new(duration : Float, ?parent) {
		this.duration = duration;
		super(parent);
		initComponent();
		
		playBtn.onClick = r -> if(!r) playing = !playing;

		prevTurnBtn.onClick = r -> if (!r) {
			playing = false;
			time = hxd.Math.floor(time) - 1;
		}
		nextTurnBtn.onClick = r -> if (!r) {
			playing = false;
			time = hxd.Math.floor(time) + 1;
		}
		fpsBtn.onClick = r -> if (!r) onToggleFps();

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

class Console extends h2d.Flow implements h2d.domkit.Object {
	static var SRC = <console>
		<button id="toggle-btn" text="Console" />
		<flow class="panel" id="log-panel" />
	</console>

	final logs : Array<ReadOnlyArray<ServerLog>>;
	var opened(default, set) : Bool = false;
	var turn : Int = -1;

	public dynamic function onToggle(opened : Bool) {}

	public function new(logs : Array<ReadOnlyArray<ServerLog>>, ?parent) {
		this.logs = logs;
		super(parent);
		initComponent();
		logPanel.visible = false;
		toggleBtn.onClick = _ -> opened = !opened;
	}

	function set_opened(v : Bool) {
		opened = v;
		logPanel.visible = v;
		onToggle(v);
		return opened;
	}

	public function setTurn(t : Int) {
		if (logs.length == 0) return;
		t = hxd.Math.iclamp(t, 0, logs.length - 1);
		if (t == turn) return;
		turn = t;
		redraw();
	}

	function redraw() {
		logPanel.removeChildren();
		for (log in logs[turn]) {
			final line = new h2d.Text(hxd.res.DefaultFont.get(), logPanel);
			final pre = log.pid != null ? '[Player ${log.pid}] ' : "";
			line.text = '$pre${log.msg}';
			line.dom = domkit.Properties.create("text", line);
			line.dom.addClass("log");
			line.dom.addClass(Type.enumConstructor(log.severity).toLowerCase());
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
		<console(serverLogs) id="console" />
		<control-bar(timeline.duration) id="control-bar" />
	</replay-view>

	var info : HistoryHeader;
	var timeline : VisualEventTimeline;
	var serverLogs : Array<ReadOnlyArray<ServerLog>>;
	var gscFactory : Void -> GameScene;

	public function new(info : HistoryHeader, timeline : VisualEventTimeline, serverLogs : Array<ReadOnlyArray<ServerLog>>, gscFactory : Void -> GameScene) {
		super();
		this.info = info;
		this.timeline = timeline;
		this.serverLogs = serverLogs;
		this.gscFactory = gscFactory;
	}

	override function init() {
		var view = gscFactory();
		initComponent();

		controlBar.onSeek = t -> {
			viewport.seek(t);
			console.setTurn(hxd.Math.floor(t));
		}
		controlBar.onToggleFps = () -> viewport.fpsGraph.visible = !viewport.fpsGraph.visible;
		console.onToggle = opened -> viewport.eventsEnabled = !opened;
		console.setTurn(0);
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