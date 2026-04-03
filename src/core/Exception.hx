package core;

abstract class Exception extends std.haxe.Exception {}
class TimeoutException extends Exception {}
class InvalidActionException extends Exception {}
