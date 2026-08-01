package cogpit.core;

abstract class Exception extends std.haxe.Exception {}
class CrashException extends Exception {}
class TimeoutException extends Exception {}
class InvalidActionException extends Exception {}