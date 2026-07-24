package botfight.viewer.view;

import botfight.core.GameState;
import botfight.core.History;
import botfight.core.action.Action;
import botfight.viewer.widget.Button;

class ReplayView<Ts : GameState> extends View {
	static var SRC = <replay-view>
		<flow class="head">
			<text text={'Game - ${game.header.seed}'}/>
			<button id="leave-btn">
				<text text={'X'}/>
			</button>
		</flow>
	</replay-view>

	public function new(game : History<Ts, Action>) {
		super();
		initComponent();

		// @todo create timeline widget

		leaveBtn.onClick = _ -> ui.pop();
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