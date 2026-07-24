package botfight.viewer.view;

import botfight.viewer.widget.Button;

import botfight.core.GameState;
import botfight.core.History;
import botfight.core.action.Action;

@:access(botfight.Match)
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