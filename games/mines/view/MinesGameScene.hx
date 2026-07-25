package view;

import botfight.core.GameState.SUID;
import botfight.viewer.replay.GameScene;
import botfight.viewer.VisualEvent;
import server.MinesState.Robot;
import server.MinesState.Object;
import server.MinesState.Vec;
import view.MinesViewer.RobotLifetimeEvent;
import view.MinesViewer.ObjectLifetimeEvent;


class MinesGameScene extends GameScene {

	override function init(events : Array<VisualEvent>) {

		// @todo clean

		new h3d.scene.CameraController.OrbitCameraController(s3d).loadFromCamera();		

		var cube : h3d.scene.Mesh;
		var prim = new h3d.prim.Cube(1, 1, 1, true);
		prim.translate(-0.5, -0.5, -0.5);
		prim.unindex();
		prim.addNormals();

		cube = new h3d.scene.Mesh(prim, s3d);
		cube.material.color.setColor(0xFF3366CC);


		var light = new h3d.scene.fwd.DirLight(new h3d.Vector(0.5, 0.5, -1), s3d);
		light.enableSpecular = true;
		cast(s3d.lightSystem, h3d.scene.fwd.LightSystem).ambientLight.set(0.3, 0.3, 0.3);
		
		for( ev in events ) {

			var color = 0;
			var beg = hxd.Math.ceil(ev.begin);
			var pos : Vec = null;
			var robot = false;

			final objEv = Std.downcast(ev, ObjectLifetimeEvent);
			var so : Object = objEv?.resolve(beg);
			if (so != null) {
				color = 0xFF3366CC;
				pos = so.pos;
			} else {
				final objEv = Std.downcast(ev, RobotLifetimeEvent);
				var sr : Robot = objEv?.resolve(beg);
				if (sr != null) {
					color = 0xFFAA33CC;
					pos = sr.pos;
					robot = true;
				}
			}
			if( pos == null ) continue;

			var p = new h3d.prim.Cube(1, 1, 1, true);
			p.translate( -0.5, -0.5, -0.5);
			p.unindex();
			p.addNormals();
			p.addUVs();
			var m = new h3d.scene.Mesh(p, s3d);
			m.material.color.setColor(color);
			m.x = pos.x;
			m.y = pos.y;
			if( robot ) m.z = -1;
			m.material.shadows = false;
			m.scale(robot ? 1.0 : 0.5);
		}
	}

	override function onEventBegin(ev : VisualEvent) {
		trace(ev);
	}
	
	override function onEventEnd(ev : VisualEvent) {
		trace(ev);
	}

	override function update(t : Float, events : Array<VisualEvent>) {
		trace('advance at $t');
	}

	override function onResize() {
		trace("ouais");
	}
}