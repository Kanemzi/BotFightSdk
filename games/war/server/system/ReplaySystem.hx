package server.system;

import cogpit.core.GameState.WeakRef;
import server.state.WarState.Building;
import server.state.WarState.Unit;
import server.state.WarState;

/**
	Data types from this class are serialized but only used for generating
	a better replay timeline. Should never be used for turn simulation.
*/
enum BuildingReplayEvent {
	HasRecruited(u : WeakRef<Unit>);
	WasHitOutside;
	WasHitInside;
	WasConstructed;
	Said(msg : String);
}

enum UnitReplayEvent {
	HasAttacked;
	// WasHit;
	WasKickedOut(b : WeakRef<Building>);
	Said(msg : String);
}

/**
	This system is in charge of updating all the replay timeline
	generation related state.
**/
class ReplaySystem {
	public static function tick(state : WarState) {
		state.units.iter(u -> (u.replayEvents ??= []).resize(0));
		state.buildings.iter(b -> (b.replayEvents ??= []).resize(0));
	}
}