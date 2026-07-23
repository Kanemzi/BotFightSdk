package games.mines;

import core.action.Action;

enum MinesAction {
	Say(msg : String); // Displays [msg] above the robot
	Wait; // the robot won't move or perform any action
	Move(x : Int, y : Int); // Moves the robot towards point [x, y]
	Mine(x : Int, y : Int); // Drops a mine at location [x, y]. Location should be ajacent to the robot
	Spawn; // Spawns a new robot next to the robot
}