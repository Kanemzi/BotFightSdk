package view;

import core.GameState;

/*
Design : 
- A viewer takes a Runner output (directly or from a saved file for replay mode)
- Runner outputs all the informations about the games that have been played in a batch (Tournament, BO7, ...)
- It has a main menu to visualize the games outcomes / global infos (list or tournament tree), select one of them and replay it.
    - Ideally it has a spectator mode that plays all the games in a row, or a chosen subset
- Allows other features like fast GameState gen debugging.
*/

class Viewer<Ts : GameState> extends hxd.App {

}