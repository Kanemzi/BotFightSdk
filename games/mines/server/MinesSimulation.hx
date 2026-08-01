package server;

import cogpit.core.Player.PlayerId;
import cogpit.core.GameSimulation;
import cogpit.core.GameSimulation.PlayersActions;
import cogpit.core.TurnModel;
import cogpit.core.action.ActionCollector;

import server.MinesState;
import client.MinesClient;
import server.Simulation in Sim;

using server.Simulation;

class MinesSimulation extends GameSimulation<MinesState, MinesAction> {

	function init(ctx : InitContext<MinesAction>) : MinesState {
		return new MinesState(ctx.getPlayers(), ctx.rnd);
	}

	function update(state : MinesState, ctx : SimulationContext<MinesAction>) : Void {
		inline function getRobot(pid : PlayerId, i : Int) {
			return state.getPlayer(pid).robots[i];
		}

		// robot move actions
		ctx.actions((pid, a, i) -> switch (a) {
			case Move(x, y):
				var r = getRobot(pid, i);
				var t = Sim.getClosestCellAround(r.pos.x, r.pos.y, x, y);
				if (t == null)
					return; // @todo error can't move anywhere
				r.pos.x = t.x;
				r.pos.y = t.y;
			default:
		});

		// mine drop actions
		ctx.actions((pid, a, i) -> switch (a) {
			case Mine(x, y):
				if (!Sim.inGrid(x, y))
					return;
				var r = getRobot(pid, i);
				var t = new Vec(x, y);
				if (!r.pos.adjacent(t)) { // auto aim
					var p = Sim.getClosestCellAround(r.pos.x, r.pos.y, x, y, (cx, cy) -> {
						return state.isEmpty(cx, cy, true);
					});
					if (p != null) {
						t.x = p.x;
						t.y = p.y;
					}
				}
				if (t == null)
					return;

				var p = state.getPlayer(pid);
				try p.consume(Sim.MINE_COST)
				catch (_)
					return; // @todo error message

				state.objects.push(new Object(Mine, t.x, t.y));

			default:
		});

		// spawn robot actions
		ctx.actions((pid, a, i) -> switch (a) {
			case Spawn:
				var p = state.getPlayer(pid);
				var r = getRobot(pid, i);
				var sp = state.getEmptyCellAround(r.pos.x, r.pos.y);
				if (sp != null) {
					try { p.consume(Sim.ROBOT_COST);
					} catch (_)
						return; // @todo error message

					p.robots.push(new Robot(sp.x, sp.y));
				} else {
					// @todo log could no spawn robot around (x, y)
				}

			default:
		});

		// items pickup on ground
		state.forEachRobot(r -> {
			var o = state.getObjectAt(r.pos.x, r.pos.y);
			if (o == null || o.k == Mine)
				return;
			var p = state.getOwner(r);
			var qty = p.resources.get(o.k);
			p.resources.set(o.k, qty + 1);
			state.objects.remove(o);
		});

		// check mines collisions (objects and robots)
		state.forEachRobot(r -> {
			var o = state.getObjectAt(r.pos.x, r.pos.y);
			if (o?.k != Mine)
				return;
			function destroyAt(x, y) {
				var o = state.getObjectAt(x, y);
				if (o != null)
					state.objects.remove(o);
				var r = state.getRobotAt(x, y);
				if (r != null) {
					var p = state.getOwner(r);
					p.robots.remove(r);
					state.destroyRobotAt(r.pos.x, r.pos.y, ctx.rnd);
				}
			}
			destroyAt(r.pos.x, r.pos.y);
			Sim.iterCellsAround(r.pos.x, r.pos.y, destroyAt);
		});

		// spawn objects on the ground
		state.turnDrops(ctx.rnd);

		// check loses / wins
		inline function countRobots(pid : PlayerId) {
			var c = 0;
			state.forEachRobot(pid, _ -> c++);
			return c;
		}

		for (p in ctx.getAlivePlayers()) {
			if (countRobots(p) == 0)
				ctx.defeat(p);
		}
	}

	function getTurnActionProfile(state : MinesState, pid : PlayerId) return Fixed(state.getPlayer(pid).robots.length);
	
	function getTiebreakerScore(state : MinesState, pid : PlayerId) {
		var p = state.getPlayer(pid);
		return p.resources.get(Scrap) + p.resources.get(Microship) * Sim.MICROSHIP_SCORE_RATIO;
	}

	function serializeHeaderForPlayer(initialState : MinesState, pid : PlayerId) : Array<String> {
		return [
			'$pid',
			'${MinesState.WIDTH} ${MinesState.HEIGHT}'
		];
	}

	function serializeForPlayer(state : MinesState, pid : PlayerId) : Array<String> {
		var l = [];
		
		var me = state.getPlayer(pid);
		l.push('${me.resources.get(Scrap)}');
		l.push('${me.resources.get(Microship)}');
		l.push('ME ${me.robots.length}');
		for (r in me.robots)
			l.push('${r.pos.x} ${r.pos.y}');

		var foes = [];
		state.forEachRobot(r -> if (state.getOwner(r).pid != pid) foes.push(r));
		l.push('FOES ${foes.length}');
		for (f in foes)
			l.push('${f.pos.x} ${f.pos.y}');

		var mines = state.objects.filter(o -> o.k == Mine);
		l.push('MINE ${mines.length}');
		for (o in mines)
			l.push('${o.pos.x} ${o.pos.y}');

		var scrap = state.objects.filter(o -> o.k == Scrap);
		l.push('SCRAP ${scrap.length}');
		for (o in scrap)
			l.push('${o.pos.x} ${o.pos.y}');

		var microship = state.objects.filter(o -> o.k == Microship);
		l.push('MICROSHIP ${microship.length}');
		for (o in microship)
			l.push('${o.pos.x} ${o.pos.y}');

		return l;
	}

	public static function main() {
		new cogpit.Runner(MinesSimulation, MinesClient, Sys.args(), {
			version : 1,
			maxTurns : Sim.MAX_TURNS,
			firstTurnTimeout : 1.0,
			turnTimeout : 0.5,
			turnModel : TurnModel.SimultaneousTurn,
			storageMode : Deterministic,
		});
	}
}