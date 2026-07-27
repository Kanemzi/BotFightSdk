package botfight.utils;

#if !macro
class Profile {
	public static function memStart() {
		var tmp = hl.Profile.globalBits;
		tmp.set(Alloc);
		hl.Profile.globalBits = tmp;
		hl.Profile.reset();
	}

	public static function memDump() {
		hl.Profile.dump("memprofSize.dump", true, false);
		hl.Profile.dump("memprofCount.dump", false, true);
	}

	public static function start() {
		hl.Gc.enable(false);
		hl.Profile.event(ClearData);
		hl.Profile.event(Setup , "20000");
		hl.Profile.event(ResumeAll);
	}

	public static function dump() {
		hl.Profile.event(PauseAll);
		hl.Profile.event(Dump);
		if( Sys.command("hl profiler.hl --collapse-recursion") != 0 )
			throw "Could not post process profile dump, missing profiler.hl ?";
		hl.Profile.event(ClearData);
		hl.Gc.enable(true);
	}

	public static inline function event(name : String, ?code : Int) {
		hl.Profile.event(hxd.Math.imax(code, 1), name);
	}

	public static inline function measure<T>(f : Void -> T) {
		return haxe.Timer.measure(f);
	}
}
#end