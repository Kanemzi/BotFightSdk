package cogpit.client.view;

import cogpit.client.widget.Button;

import cogpit.core.GameState;
import cogpit.core.History;
import cogpit.core.action.Action;
import cogpit.live.MatchHandle;
import cogpit.client.VisualEventTimeline;
import cogpit.client.VisualEventTimeline.TimelineBuilder;
import cogpit.client.replay.GameScene;

import cogpit.live.LiveChannel.LiveEvent;

@:access(cogpit.Match)
class MatchView<Ts : GameState> extends View {
	static var SRC = <match-view>
		<flow class="head">
			<text text={'${match.toString()} - ${match.seed}'} />
		</flow>
		<flow class="game-list">
			for (g in match.games) {
				<button class="game-btn" id="match-btn[]" onClick={onClickGame.bind(_, g.history)} text={'${g.name} - ${g.history.header.seed}'} if(!g.status.match(Empty|Ready))/>
			}
		</flow>
	</match-view>

	var match : MatchHandle<Ts, Action>;
	var tb : TimelineBuilder<Ts>;
	var gscFactory : Void -> GameScene;

	public function new(match : MatchHandle<Ts, Action>, tb : TimelineBuilder<Ts>, gscFactory : Void -> GameScene) {
		super();
		this.match = match;
		this.tb = tb;
		this.gscFactory = gscFactory;
	}

	override function init() {
		final onClickGame = (r, g) -> {
			var tl = tb.bake(g);
			r ? openTimeline(tl) : openReplay(g.header, tl, gscFactory);
		}
		initComponent();
	}

	function openReplay(info : HistoryHeader, timeline : VisualEventTimeline, gscFactory : Void -> GameScene) {
		ui.push(new ReplayView(info, timeline , gscFactory));
	}

	function openTimeline(timeline : VisualEventTimeline) {
		ui.push(new TimelineDebugView(timeline));
	}

	override function onLiveEvent(ev : LiveEvent) {
		switch (ev) {
			case GameBegin:
				rebuild();
			default:
		}
	}
}