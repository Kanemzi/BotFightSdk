package server;

import botfight.core.action.Action;

// @todo macro should support multiple optional non strings params at the end of the line (default radius)

// @todo game turns are really short, since the simulation has a lot of micro and needs to be precise. But de players won't take decisions each turn (maybe every 10-20 turns).

/** Turn protocol
	- Bot sends multiple actions then and End action to finish its turn.
	- Max 1 action of each kind per building BUT
		- Some actions are decisions. Multiple different decisions can be sent per building
		- Some actions are targeted. Only 1 targeted decision per building
	ex: 
	Can't request (Gather + Build) or (Attack + Move) on same building in the same turn.
	But can request (Gather + Say). Limited to 1 say per building/turn
	Spawn has no target, therefore we can (Attack + Say + Spawn) on 1 building in the same turn.
**/

enum WarAction {
	/* All */
	Say(bid : Int, onUnit : Int, msg : String); // Displays a [msg] from [bid] (or closest unit to the current targetPoint if [onUnit] == 1)
	Move(bid : Int, x : Float, y : Float, radius : Float); // Units on [bid] will go and stay stationary in a [radius] around [x, y]
	Spawn(bid : Int, unit : Word); // Spawn a new unit in [bid]. Cost will depend on the [unit] type

	/* Economy*/
	Gather(bid : Int, x : Float, y : Float, radius : Float); // Units of [bid] will gather freely in a [radius] around [x, y]
	Build(bid : Int, x : Float, y : Float, building : Word); // Units of [bid] will start to build a [building] of type (HOUSE|TOWER)] at [x, y] // @todo building should be optional (in case construction site is already placed)

	/* Military */
	Attack(bid : Int, tid : Int); // Units of [bid] will attack building [tid]

	End; // Finishes the turn
}