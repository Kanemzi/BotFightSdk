package games.mines;

import core.GameServer;
import core.Player;
import core.TurnModel;
import core.action.ActionCollector;

import games.mines.MinesState;
import games.mines.view.MinesViewer;
import games.mines.Simulation in Sim;

using games.mines.Simulation;

class MinesServer extends GameServer<MinesState, MinesAction> {
	public function new(seed : Int) {
		super(seed, {
			version : "0.1",
			minPlayers : 2,
			maxPlayers : 2,
			maxTurns : Sim.MAX_TURNS,
			firstTurnTimeout : 1000.0,
			turnTimeout : 1000.0,
			turnModel : TurnModel.SimultaneousTurn,
		});
	}

	function init() : MinesState {
		return new MinesState(players.map(p -> p.id), seed);
	}

	function update(state : MinesState, actions : PlayersActions<MinesAction>) : Void {
		inline function getRobot(pid : PlayerId, i : Int) {
			return state.getPlayer(pid).robots[i];
		}

		// robot move actions
		actions((pid, a, i) -> switch (a) {
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
		actions((pid, a, i) -> switch (a) {
			case Mine(x, y):
				if (!Sim.inGrid(x, y))
					return;
				var r = getRobot(pid, i);
				if (!r.pos.adjacent(new Vec(x, y)))
					return;

				var p = state.getPlayer(pid);
				try p.consume(Sim.MINE_COST)
				catch (_)
					return; // @todo error message

				state.objects.push(new Object(Mine, x, y));

			default:
		});

		// spawn robot actions
		actions((pid, a, i) -> switch (a) {
			case Spawn:
				var p = state.getPlayer(pid);
				var r = getRobot(pid, i);
				var sp = state.getEmptyCellAround(r.pos.x, r.pos.y);
				if (sp != null) {
					try p.consume(Sim.MINE_COST)
					catch (_)
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
			if (o.k != Mine)
				return;
			function destroyAt(x, y) {
				var o = state.getObjectAt(x, y);
				if (o != null)
					state.objects.remove(o);
				var r = state.getRobotAt(x, y);
				if (r != null) {
					var p = state.getOwner(r);
					p.robots.remove(r);
					state.destroyRobotAt(r.pos.x, r.pos.y, state.genRand(r.id));
				}
			}
			destroyAt(r.pos.x, r.pos.y);
			Sim.iterCellsAround(r.pos.x, r.pos.y, destroyAt);
		});

		// spawn objects on the ground
		var rnd = state.genRand(turn);
		state.turnDrops(rnd);

		// check loses / wins
	}

	function getTurnActionProfile(pid : PlayerId) return Fixed(state.getPlayer(pid).robots.length );
	function getTiebreakerScore(pid : PlayerId) {
		var p = state.getPlayer(pid);
		return p.resources.get(Scrap) + p.resources.get(Microship) * Sim.MICROSHIP_SCORE_RATIO;
	}

	public static function main() {
		new Runner(MinesServer, MinesViewer, Sys.args());
	}
}