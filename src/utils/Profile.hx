package utils;

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
}
#end