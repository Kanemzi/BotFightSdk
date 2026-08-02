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
	static inline final GEN_EXT = "gen";

	@:access(cogpit.Match)
	static function writeMatch<Ts : GameState, Ta : Action>(out : String, match : Match<Ts, Ta>, ext : String) {
		final bytes = haxe.zip.Compress.run(hxbit.Serializer.save(match), 2);
		var path = new haxe.io.Path(out ?? ".");
		path.ext = ext;
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

	static function readMatch<Ts : GameState, Ta : Action>(path : String, ext : String) : Match<Ts, Ta> {
		var p = new haxe.io.Path(path);
		p.ext = ext;
		path = p.toString();

		if (!sys.FileSystem.exists(path))
			throw ('Replay file $path does not exist');

		try {
			final bytes = haxe.zip.Uncompress.run(sys.io.File.getBytes(path));
			final match : Match<Ts, Ta> = cast hxbit.Serializer.load(bytes, Match);
			return match;
		} catch (e : Exception) {
			throw 'Could not read match file $path : ${e.details()}';
		}
	}

	@:access(cogpit.Match)
	public static function saveMatch<Ts : GameState, Ta : Action>(out : String, match : Match<Ts, Ta>, ?mode : StorageMode) {
		// Save a deep copy of the match when a live client is attached to it, to avoid breaking references during optimize
		if (match.live != null)
			match = cast serializer.unserialize(cast serializer.serialize(match), Match);

		for (g in match.games) g.history.optimize(mode);
		writeMatch(out, match, REPLAY_EXT);
	}

	public static function loadMatch<Ts : GameState, Ta : Action>(path : String) : Match<Ts, Ta> {
		return readMatch(path, REPLAY_EXT);
	}

	public static function saveGen<Ts : GameState, Ta : Action>(out : String, match : Match<Ts, Ta>) {
		writeMatch(out, match, GEN_EXT);
	}

	@:access(cogpit.Match)
	public static function loadGen<Ts : GameState, Ta : Action>(path : String) : Ts {
		var m = readMatch(path, GEN_EXT);
		return m.games[0].history.turns[0].state;
	}
}