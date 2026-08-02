package cogpit.client.replay;

class Gizmos {
	var g3d : h3d.scene.Graphics;
	var g2d : h2d.Graphics;
	var s2d : h2d.Object;
	var camera : h3d.Camera;
	var texts : Array<{t : h2d.Text, ?pos : h3d.col.Point}> = [];

	public static function make2d(s2d : h2d.Object) : Gizmos {
		final g = new Gizmos();
		g.s2d = s2d;
		g.g2d = new h2d.Graphics(s2d);
		return g;
	}

	/**
		Prepares a Gizmos for 3d debugging.
		[s2d] must be passed for 3d text debug to work
	*/
	public static function make3d(s3d : h3d.scene.Scene, ?s2d : h2d.Object) : Gizmos {
		final g = new Gizmos();
		g.g3d = new h3d.scene.Graphics(s3d);
		g.camera = s3d.camera;
		if (s2d != null) {
			g.s2d = s2d;
			g.g2d = new h2d.Graphics(s2d);
		}
		return g;
	}

	function new() {}

	public function clear() {
		g2d?.clear();
		g3d?.clear();
		texts.keep(t -> { t.t.remove(); return false; });
	}

	public function line(a : h3d.col.Point, b : h3d.col.Point, color = 0xff0000) {
		if (g3d != null) {
            g3d.lineStyle(1, color);
            g3d.moveTo(a.x, a.y, a.z);
            g3d.lineTo(b.x, b.y, b.z);
            g3d.lineStyle(0);
        } else {
			g2d.lineStyle(1, color);
            g2d.moveTo(a.x, a.y);
            g2d.lineTo(b.x, b.y);
            g2d.lineStyle(0);
        }
	}

	public function circle(center : h3d.col.Point, radius : Float, segments = 16, color = 0xff0000) {
		var prev : h3d.col.Point = null;
		for (i in 0...segments + 1) {
			final a = i / segments * Math.PI * 2;
			final p = new h3d.col.Point(center.x + Math.cos(a) * radius, center.y + Math.sin(a) * radius, center.z);
			if (prev != null) line(prev, p, color);
			prev = p;
		}
	}

	public function text(pos : h3d.col.Point, str : String, color = 0xffffff) : Void {
		var x = pos.x;
		var y = pos.y;
		final is3d = g3d != null;
		if (is3d) {
			if (s2d == null) throw 'No 2D scene provided to 3D Gizmos. text() not supported';
			final scene = s2d.getScene();
			final proj = camera.project(pos.x, pos.y, pos.z, scene.width, scene.height);
			x = proj.x;
			y = proj.y;
		}

		final t = new h2d.Text(hxd.res.DefaultFont.get(), s2d);
		t.text = str;
		t.textColor = color;
		t.x = x;
		t.y = y;
		texts.push({t: t, pos : is3d ? pos : null});
	}

	public function refresh() : Void {
		if (camera == null || s2d == null) return;
		final scene = s2d.getScene();
		texts.iter(t -> {
			if (t.pos == null) return;
			final proj = camera.project(t.pos.x, t.pos.y, t.pos.z, scene.width, scene.height);
			t.t.x = proj.x;
			t.t.y = proj.y;
		});
	}
}