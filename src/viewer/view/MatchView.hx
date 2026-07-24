package viewer.view;

import viewer.widget.Button;

import core.GameState;
import core.History;
import core.action.Action;

@:access(Match)
class MatchView<Ts : GameState> extends View {
	static var SRC = <match-view>
		<flow class="head">
			<text text={'${match.toString()} - ${match.seed}'}/>
		</flow>
		<flow class="game-list">
			for (i => g in match.games) {
				<button class="game" id="match-btn[]" onClick={_ -> openReplay(g)}>
					<text text={'${i + 1} - ${g.header.seed}'}/>
				</button>
			}
		</flow>
	</match-view>

	public function new(match : Match<Ts, Action>) {
		super();
		initComponent();
	}

	function openReplay(game : History<Ts, Action>) {
		ui.push(new ReplayView(game));
	}
}