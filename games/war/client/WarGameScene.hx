package client;

import cogpit.client.replay.GameScene;
import cogpit.client.VisualEvent;
import cogpit.client.VisualEvent.EventId;
import cogpit.core.Player.PlayerId;
import client.WarClient.UnitLifetimeEvent;
import client.WarClient.BuildingLifetimeEvent;
import client.WarClient.ResourceLifetimeEvent;
import server.state.WarState.Unit;
import server.state.WarState.Building;
import server.state.WarState.Resource;
import server.state.WarState.Vec;

private typedef Visual = { mesh : h3d.scene.Object }

class WarGameScene extends GameScene {

	var visuals : Map<EventId, Visual>;

	override function init(events : ReadOnlyArray<VisualEvent>) {
		visuals = new Map();

		fitCameraTopDown();
		new h3d.scene.CameraController.OrbitCameraController(s3d).loadFromCamera();

		var light = new h3d.scene.fwd.DirLight(new h3d.Vector(0.5, 0.5, -1), s3d);
		light.enableSpecular = true;
		cast(s3d.lightSystem, h3d.scene.fwd.LightSystem).ambientLight.set(0.3, 0.3, 0.3);

		final thickness = 0.1;
		var groundPrim = new h3d.prim.Cube(Const.Width, Const.Height, thickness, true);
		groundPrim.addNormals();
		var ground = new h3d.scene.Mesh(groundPrim, s3d);
		ground.material.color.setColor(0xFF33512A);
		ground.material.shadows = false;
		ground.x = Const.Width / 2;
		ground.y = Const.Height / 2;
		ground.z = -thickness / 2;
	}

	function fitCameraTopDown() {
		final cam = s3d.camera;
		final cx = Const.Width / 2;
		final cy = Const.Height / 2;

		final halfV = Math.tan(cam.fovY * Math.PI / 180 / 2);
		final halfH = halfV * cam.screenRatio;
		final distV = (Const.Height / 2) / halfV;
		final distH = (Const.Width / 2) / halfH;
		final dist = hxd.Math.max(distV, distH);

		final eps = dist * 1e-3;
		cam.pos.set(cx + eps, cy, dist);
		cam.target.set(cx, cy, 0);
	}

	static final TEAM_COLORS = [0xFF3388CC, 0xFFCC5533];
	static final NEUTRAL_COLOR = 0xFF999999;

	static inline function teamColor(pid : Null<PlayerId>) : Int
		return pid == null ? NEUTRAL_COLOR : TEAM_COLORS[pid % TEAM_COLORS.length];

	function makeUnitMesh(kind : Data.UnitKind, color : Int) : h3d.scene.Mesh {
		var p = new h3d.prim.Cube(0.6, 0.6, 1.2, true);
		p.translate(-0.3, -0.3, 0);
		p.addNormals();

		var m = new h3d.scene.Mesh(p, s3d);
		m.material.color.setColor(color);
		m.material.shadows = false;
		return m;
	}

	function makeBuildingMesh(kind : Data.BuildingKind, color : Int) : h3d.scene.Mesh {
		final size = switch (kind) {
			case House: 2.;
			case Outpost: 2.5;
			case Laboratory: 2.2;
		}
		var p = new h3d.prim.Cube(size, size, size * 0.8, true);
		p.translate(-size / 2, -size / 2, 0);
		p.addNormals();

		var m = new h3d.scene.Mesh(p, s3d);
		m.material.color.setColor(color);
		m.material.shadows = false;
		return m;
	}

	static final RESOURCE_COLORS : Map<Data.ResourceKind, Int> = [
		Food => 0xFF66CC66,
		Materials => 0xFF997755,
		Bravery => 0xFFCCCC33,
	];

	function makeResourceMesh(kind : Data.ResourceKind) : h3d.scene.Mesh {
		var p = new h3d.prim.Sphere(0.4, 10, 6);
		p.addNormals();

		var m = new h3d.scene.Mesh(p, s3d);
		m.material.color.setColor(RESOURCE_COLORS.get(kind) ?? 0xFFFFFFFF);
		m.material.shadows = false;
		m.z = 0.4;
		return m;
	}

	// A garrisoned unit has no visual event (hidden), so its lifetime event is only ever
	// active while UnitPos.Terrain(pos) holds.
	function resolveUnitPos(u : Unit) : Vec {
		return switch (u.pos) {
			case Terrain(pos): pos;
			case Building(_): null;
		}
	}

	override function onEventBegin(ev : VisualEvent) {
		final turn = hxd.Math.ceil(ev.begin);

		final b = Std.downcast(ev, BuildingLifetimeEvent);
		if (b != null) {
			final building = b.resolve(turn);
			if (building == null) return;

			final m = makeBuildingMesh(building.kind, teamColor(building.clan?.pid));
			m.x = building.pos.x;
			m.y = building.pos.y;
			visuals.set(ev.id, { mesh : m });
			return;
		}

		final r = Std.downcast(ev, ResourceLifetimeEvent);
		if (r != null) {
			final res = r.resolve(turn);
			if (res == null) return;

			final m = makeResourceMesh(res.kind);
			m.x = res.pos.x;
			m.y = res.pos.y;
			visuals.set(ev.id, { mesh : m });
			return;
		}

		final u = Std.downcast(ev, UnitLifetimeEvent);
		if (u != null) {
			final unit = u.resolve(turn);
			if (unit == null) return;

			final m = makeUnitMesh(unit.kind, teamColor(unit.clan?.pid));
			final pos = resolveUnitPos(unit);
			if (pos != null) { m.x = pos.x; m.y = pos.y; }
			visuals.set(ev.id, { mesh : m });
		}
	}

	override function onEventEnd(ev : VisualEvent) {
		final v = visuals.get(ev.id);
		if (v == null) return;

		v.mesh.remove();
		visuals.remove(ev.id);
	}

	override function update(t : Float, events : ReadOnlyArray<VisualEvent>) {
		final t0 = hxd.Math.floor(t);
		final t1 = hxd.Math.ceil(t);
		final k = t - t0;

		for (ev in events) {
			final v = visuals.get(ev.id);
			if (v == null) continue;

			// Bâtiments/ressources sont statiques (placés une fois dans onEventBegin) ;
			// seul le clan propriétaire d'un bâtiment peut changer, donc on relit sa couleur.
			final b = Std.downcast(ev, BuildingLifetimeEvent);
			if (b != null) {
				final building = b.resolve(t1) ?? b.resolve(t0);
				final mesh = Std.downcast(v.mesh, h3d.scene.Mesh);
				if (building != null && mesh != null)
					mesh.material.color.setColor(teamColor(building.clan?.pid));
				continue;
			}

			final u = Std.downcast(ev, UnitLifetimeEvent);
			if (u == null) continue;

			final unit0 = u.resolve(t0);
			final unit1 = u.resolve(t1);
			var p0 = unit0 != null ? resolveUnitPos(unit0) : null;
			var p1 = unit1 != null ? resolveUnitPos(unit1) : null;
			if (p0 == null) p0 = p1;
			if (p1 == null) p1 = p0;
			if (p0 == null) continue;

			v.mesh.x = hxd.Math.lerp(p0.x, p1.x, k);
			v.mesh.y = hxd.Math.lerp(p0.y, p1.y, k);
		}
	}

	override function onResize() {
		fitCameraTopDown();
	}
}
