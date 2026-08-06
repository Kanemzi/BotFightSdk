package server.state;

import cogpit.core.GameState.State;
import cogpit.core.GameState.WeakRef;

@:forward(get, set, remove, keys, iterator, keyValueIterator)
abstract Resources(Map<Data.ResourceKind, Int>) {
	public function new() { this = new Map(); }
	@:from static function fromData(d : cdb.Types.ArrayRead<Data.Types_resources>) {
		final res = new Map();
		for (r in d) {
			final a = (res.get(r.itemId) ?? 0) + r.amount;
			res.set(r.itemId, a);
		}
		return cast res;
	}
}

/**
	Inventory with an optional fallback to a parent inventory to withdraw
	when lacking resources.
**/
class Inventory extends State {
	@:s var res : Resources;
	@:s var fallback(default, null) : Null<WeakRef<Inventory>>;

	public function new() {
		super();
		res = new Resources();
	}

	public function fallbackTo(fallback : Null<Inventory>) {
		this.fallback = (fallback : Null<WeakRef<Inventory>>);
	}

	public function get(k : Data.ResourceKind, local = false) : Int {
		return (res.get(k) ?? 0) + (local ? 0 : fallback?.get()?.get(k, true) ?? 0);
	}

	public function has(k : Data.ResourceKind, amount : Int, local = false) {
		return get(k) >= amount;
	}

	public function hasAll(res : Resources, local = false) {
		for (k => a in res) if (!has(k, a, local)) return false;
		return true;
	}

	public function add(k : Data.ResourceKind, amount : Int) : Bool {
		if (amount >= 0) {
			res.set(k, (res.get(k) ?? 0) + amount);
			return true;
		}

		final local = res.get(k) ?? 0;
		final remain = local + amount; 
		if (remain >= 0) {
			if (remain == 0) res.remove(k);
			else res.set(k, remain);
			return true;
		}

		if (fallback == null || !fallback.get()?.add(k, remain))
			return false;

		res.remove(k);
		return true;
	}

	public function addAll(res : Resources) {
		for (k => a in res) if (a < 0 && !has(k, -a)) return false;
		for (k => a in res) if (!add(k, a)) return false;
		return true;
	}

	public inline function consume(k : Data.ResourceKind, amount : Int) : Bool {
		return add(k, amount >= 0 ? amount : -amount);
	}

	public function consumeAll(res : Resources) {
		if (!hasAll(res)) return false;
		for (k => a in res) if (!consume(k, a)) return false;
		return true;
	}

	public function toString(local = false) {
		final ids = [];
		listItemKinds(ids, local);
		final list = [for (k in ids) '$k => ${get(k, local)}'];
		return '[${list.join(", ")}]';
	}

	function listItemKinds(out : Array<Data.ResourceKind>, local : Bool) {
		for (i in res.keys()) out.pushUnique(i);
		if (!local) fallback?.get()?.listItemKinds(out, false);
	}
}