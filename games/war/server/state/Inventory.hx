package server.state;

typedef Resources = Map<Data.ResourceKind, Int>;

abstract Inventory(Resources) {
	public function new() {
		this = new Map();
	}

	public function has(res : Data.ResourceKind, amount : Int) {
		final a = this.get(k);
		return a != null && a >= amount;
	}

	public function hasAll(res : Resources) {
		for (k => a in res) if (!has(k, a)) return false;
		return true;
	}

	public function add(res : Data.ResourceKind, amount : Int) : Bool {
		final a = this.get(k);
		if (amount < 0 && !has(res, -amount))
			return false;
		res.set(k, a + amount);
		return true;
	}

	public function addAll(res : Resources) {
		for (k => a in res) if (a < 0 && !has(k, -a)) return false;
		for (k => a in res) if (!add(k, a)) return false;
		return true;
	}

	public function consume(res : Data.ResourceKind, amount : Int) : Bool {
		if (amount > 0) amount *= -1;
		return add(res, amount);
	}
	
	public function consumeAll(res : Resources) {
		if (!hasAll(res)) return false;
		for (k => a in res) if (!consume(k, a)) return false;
		return true;
	}
}