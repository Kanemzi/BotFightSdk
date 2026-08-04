package server.simulation;

import server.state.WarState.Building;

@:publicFields class BuildingAction {
	
	/**
		The replay will display the text [msg] above the building (or closest unit
		to order target if [onUnit]).
	*/
	static inline function say(b : Building, msg : String, onUnit : Bool) {
		b.sayInfo = {msg : msg, onUnit : onUnit, expire : Const.SayActionDuration};
	}

	/**
		Simulates one tick of [u] placing a resource in the building durability (construct or repair).
		@return false when the player does not have enough resources.
	*/
	static function construct(b : Building, u : Unit, state : WarState) : Bool {
		final uOwner = u.building.get().owner;
		assert(!u.isOrphan);
		assert(leading == null || leading == uOwner);

		final cost = getCost();
		if (!uOwner.inv.has(Wood, cost)) return false;

		changeDurability(1, uOwner);		
		uOwner.inv.consume(Wood, 1);
		// change leading
		return true;
	}
}