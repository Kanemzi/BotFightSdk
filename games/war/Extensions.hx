class Extensions {
	public static function toPascalCase(str : String) : String {
		var words = ~/[^a-zA-Z0-9]+/g.split(str);
		var out = new StringBuf();
		for (w in words) {
			if (w.length == 0) continue;
			out.add(w.substr(0, 1).toUpperCase());
			out.add(w.substr(1).toLowerCase());
		}
		return out.toString();
	}
}