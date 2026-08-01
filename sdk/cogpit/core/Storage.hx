package cogpit.core;

import haxe.crypto.Md5;
import cogpit.core.action.Action;
import cogpit.core.GameState;

enum StorageMode {
	Full; // Safest but heavy. Each turn is deep copied.
	Delta; // A bit less safe. For each State that is unchanged in the next GameState, the same ref will be used instead of a deep copy.
	Deterministic; // Light but risky, the game must be fully deterministic. Only the initial GameState is saved, and the player actions. The whole history is simulated again.
}

class Storage {
	public static var serializer(get, default) : hxbit.Serializer;
	static function get_serializer() {
		if (serializer != null) return serializer;
		serializer = new hxbit.Serializer();
		serializer.remapIds = true;
		return serializer;
	}

	static inline final REPLAY_EXT = "replay"; 
	@:access(cogpit.Match)
	public static function saveMatch<Ts : GameState, Ta : Action>(out : String, match : Match<Ts, Ta>, ?mode : StorageMode) {
		// Save a deep copy of the match when a live client is attached to it, to avoid breaking references during optimize
		if (match.live != null)
			match = cast serializer.unserialize(cast serializer.serialize(match), Match);
		
		for (g in match.games) g.history.optimize(mode);

		final bytes = haxe.zip.Compress.run(serializer.serialize(match), 2);
		var path = new haxe.io.Path(out ?? ".");
		path.ext = REPLAY_EXT;
		// @todo checkDeterministic (bruteforce many games with different seeds to ensure the outcome is always the same)
		if (path.file.length == 0)
			path.file = Md5.encode('${match.seed}');

		if (path.dir != null && !sys.FileSystem.exists(path.dir) )
			sys.FileSystem.createDirectory(path.dir);

		var v = 0;
		var f = path.file;
		do {
			path.file = f + (v > 0 ? '_$v' : '');
			v++;
		} while (sys.FileSystem.exists(path.toString()));

		sys.io.File.saveBytes(path.toString(), bytes);
	}

	@:access(cogpit.Match)
	public static function loadMatch<Ts : GameState, Ta : Action>(path : String) : Match<Ts, Ta> {
		var p = new haxe.io.Path(path);
		p.ext = REPLAY_EXT;
		path = p.toString();
		
		if (!sys.FileSystem.exists(path))
			throw ('Replay file $path does not exist');
		
		try { 
			// @todo using "save/load" instead to keep versioning 
			final bytes = sys.io.File.getBytes(path);
			return serializer.unserialize(haxe.zip.Uncompress.run(bytes), Match);
		} catch (e : Exception) {
			throw 'Could not read match file $path : ${e.details()}';
		}
	}
}