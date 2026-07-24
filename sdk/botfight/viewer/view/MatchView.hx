package botfight.viewer.view;

import botfight.viewer.widget.Button;

import botfight.core.GameState;
import botfight.core.History;
import botfight.core.action.Action;
import botfight.viewer.VisualEventTimeline;
import botfight.viewer.VisualEventTimeline.TimelineBuilder;

@:access(botfight.Match)
class MatchView<Ts : GameState> extends View {
	static var SRC = <match-view>
		<flow class="head">
			<text text={'${match.toString()} - ${match.seed}'} />
		</flow>
		<flow class="game-list">
			for (i => g in match.games) {
				<button class="game" id="match-btn[]" onClick={onClickGame.bind(_, g)}>
					<text text={'${i + 1} - ${g.header.seed}'} />
				</button>
			}
		</flow>
	</match-view>

	public function new(match : Match<Ts, Action>, tb : TimelineBuilder<Ts>) {
		super();
		final onClickGame = (r, g) -> r ? openTimeline(tb.bake(g)) : openReplay(g);
		initComponent();
	}

	function openReplay(game : History<Ts, Action>) {
		ui.push(new ReplayView(game));
	}

	function openTimeline(timeline : VisualEventTimeline) {
		ui.push(new TimelineDebugView(timeline));
	}
}