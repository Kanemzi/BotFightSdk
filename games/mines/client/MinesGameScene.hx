package client;

import cogpit.core.GameState.SUID;
import cogpit.client.replay.GameScene;
import cogpit.client.VisualEvent;
import cogpit.client.VisualEvent.EventId;
import server.MinesState;
import server.MinesState.Robot;
import server.MinesState.Object;
import server.MinesState.ObjectKind;
import server.MinesState.Vec;
import client.MinesClient.RobotLifetimeEvent;
import client.MinesClient.ObjectLifetimeEvent;

private typedef Visual = {
	var mesh : h3d.scene.Object;
	var robot : Bool;
}

class MinesGameScene extends GameScene {

	var visuals : Map<EventId, Visual>;

	override function init(events : ReadOnlyArray<VisualEvent>) {
		visuals = new Map();

		fitCameraTopDown();
		new h3d.scene.CameraController.OrbitCameraController(s3d).loadFromCamera();

		var light = new h3d.scene.fwd.DirLight(new h3d.Vector(0.5, 0.5, -1), s3d);
		light.enableSpecular = true;
		cast(s3d.lightSystem, h3d.scene.fwd.LightSystem).ambientLight.set(0.3, 0.3, 0.3);

		final thickness = 0.1;
		var groundPrim = new h3d.prim.Cube(MinesState.WIDTH, MinesState.HEIGHT, thickness, true);
		groundPrim.addNormals();
		var ground = new h3d.scene.Mesh(groundPrim, s3d);
		ground.material.color.setColor(0xFFFFFFFF);
		ground.material.shadows = false;
		ground.x = (MinesState.WIDTH - 1) / 2;
		ground.y = (MinesState.HEIGHT - 1) / 2;
		ground.z = -thickness / 2;
	}

	function fitCameraTopDown() {
		final cam = s3d.camera;
		final cx = (MinesState.WIDTH - 1) / 2;
		final cy = (MinesState.HEIGHT - 1) / 2;

		final halfV = Math.tan(cam.fovY * Math.PI / 180 / 2);
		final halfH = halfV * cam.screenRatio;
		final distV = (MinesState.HEIGHT / 2) / halfV;
		final distH = (MinesState.WIDTH / 2) / halfH;
		final dist = hxd.Math.max(distV, distH);

		final eps = dist * 1e-3;
		cam.pos.set(cx + eps, cy, dist);
		cam.target.set(cx, cy, 0);
	}

	function resolvePos(ev : VisualEvent, turn : Int) : Vec {
		final objEv = Std.downcast(ev, ObjectLifetimeEvent);
		if (objEv != null) return objEv.resolve(turn)?.pos;

		final robEv = Std.downcast(ev, RobotLifetimeEvent);
		if (robEv != null) return robEv.resolve(turn)?.pos;

		return null;
	}

	static final TEAM_COLORS = [0xFFAA33CC, 0xFF33CC66];

	function makeRobotMesh(team : Int) : h3d.scene.Object {
		var p = new h3d.prim.Cube(1, 1, 1, false);
		p.translate(-0.5, -0.5, 0);
		p.unindex();
		p.addNormals();

		var m = new h3d.scene.Mesh(p, s3d);
		m.material.color.setColor(TEAM_COLORS[team]);
		m.material.shadows = false;
		m.scale(0.7);
		m.scaleZ = 2;
		return m;
	}

	function makeObjectMesh(k : ObjectKind) : h3d.scene.Object {
		var m : h3d.scene.Object;

		switch (k) {
			case Mine:
				final ray = 0.35;
				var sphere = new h3d.prim.Sphere(ray, 12, 8);
				sphere.addNormals();
				var mesh = new h3d.scene.Mesh(sphere, s3d);
				mesh.material.color.setColor(0xFFCC2222);
				mesh.material.shadows = false;
				mesh.z = ray;
				m = mesh;

			case Scrap:
				var cube = new h3d.prim.Cube(1, 1, 1, false);
				cube.translate(-0.5, -0.5, 0);
				cube.unindex();
				cube.addNormals();
				var mesh = new h3d.scene.Mesh(cube, s3d);
				mesh.material.color.setColor(0xFF998866);
				mesh.material.shadows = false;
				mesh.scale(0.4);
				m = mesh;

			case Microship:
				final ray = 0.25;
				final height = 0.6;
				final color = 0xFF33CCAA;

				var container = new h3d.scene.Object(s3d);

				var cyl = new h3d.prim.Cylinder(8, ray, height, false);
				cyl.addNormals();
				var body = new h3d.scene.Mesh(cyl, container);
				body.material.color.setColor(color);
				body.material.shadows = false;

				var bottomCap = new h3d.prim.Disc(ray, 8);
				bottomCap.addNormals();
				var bottom = new h3d.scene.Mesh(bottomCap, container);
				bottom.material.color.setColor(color);
				bottom.material.shadows = false;
				bottom.material.mainPass.culling = None;

				var topCap = new h3d.prim.Disc(ray, 8);
				topCap.addNormals();
				var top = new h3d.scene.Mesh(topCap, container);
				top.material.color.setColor(color);
				top.material.shadows = false;
				top.material.mainPass.culling = None;
				top.z = height;

				m = container;
		}

		return m;
	}

	override function onEventBegin(ev : VisualEvent) {
		final robotEv = Std.downcast(ev, RobotLifetimeEvent);
		final objEv = Std.downcast(ev, ObjectLifetimeEvent);
		if (robotEv == null && objEv == null) return;

		var m : h3d.scene.Object;
		if (robotEv != null) {
			m = makeRobotMesh(robotEv.team);
		} else {
			final o = objEv.resolve(hxd.Math.ceil(ev.begin));
			m = makeObjectMesh(o != null ? o.k : Scrap);
		}

		final pos = resolvePos(ev, hxd.Math.ceil(ev.begin));
		if (pos != null) {
			m.x = pos.x;
			m.y = pos.y;
		}

		visuals.set(ev.id, { mesh : m, robot : robotEv != null });
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

			var p0 = resolvePos(ev, t0);
			var p1 = resolvePos(ev, t1);
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
