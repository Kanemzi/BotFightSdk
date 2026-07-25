package botfight.viewer.view;

import botfight.viewer.widget.Button;

import botfight.core.GameState;
import botfight.core.History;
import botfight.core.action.Action;
import botfight.viewer.VisualEventTimeline;
import botfight.viewer.VisualEventTimeline.TimelineBuilder;
import botfight.viewer.replay.GameScene;

@:access(botfight.Match)
class MatchView<Ts : GameState> extends View {
	static var SRC = <match-view>
		<flow class="head">
			<text text={'${match.toString()} - ${match.seed}'} />
		</flow>
		<flow class="game-list">
			for (i => g in match.games) {
				<button class="game" id="match-btn[]" onClick={onClickGame.bind(_, g)} text={'${i + 1} - ${g.header.seed}'} />
			}
		</flow>
	</match-view>

	public function new(match : Match<Ts, Action>, tb : TimelineBuilder<Ts>, gscFactory : Void -> GameScene) {
		super();
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
}