package viewer.view;

import viewer.widget.Widget;

class ReplayView extends View {
	static var SRC = <replay-view>
		<widget class="truc"></widget>
	</replay-view>
}

/**
	Design for replay mode :
	
	Input : a timeline of abstract events. Events are linked to States

	The replay holds a heaps scene with visual objects that should be updated depending
	on events or related states.
	
	It can update the scene from a state of a specific turn, to the immediate next or 
	previous step (or interpolate between them).
	



*/