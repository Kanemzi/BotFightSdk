package client;

import server.state.WarState;
import server.state.WarState.Unit;
import server.state.WarState.Building;
import server.state.WarState.Resource;

import cogpit.client.VisualEventTimeline.TimelineBuilder;
import cogpit.client.VisualEventTimeline.LifetimeRule;
import cogpit.client.VisualEvent;

@color(0x33aa55)
class UnitLifetimeEvent extends StateVisualEvent<Unit> {}

@color(0x8899aa)
class BuildingLifetimeEvent extends StateVisualEvent<Building> {}

@color(0xccaa33)
class ResourceLifetimeEvent extends StateVisualEvent<Resource> {}

class WarClient extends cogpit.client.GameClient<WarState> {
	function getTimelineBuilder() return new TimelineBuilder()
		.addRule(new LifetimeRule<WarState, Unit>(gs -> gs.units.filter(u -> !u.inside()), u -> new UnitLifetimeEvent(u)))
		.addRule(new LifetimeRule<WarState, Building>(gs -> gs.buildings, b -> new BuildingLifetimeEvent(b)))
		.addRule(new LifetimeRule<WarState, Resource>(gs -> gs.resources, r -> new ResourceLifetimeEvent(r)));

	function getScene() return new WarGameScene();
}
