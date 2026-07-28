package botfight;

#if !macro
@:build(hxd.res.FileTree.build("sdk/botfight/res", "botfight"))
#end
class Res {
	static var RES = "sdk/botfight/res";

	#if !macro
	static public var fs : hxd.fs.FileSystem;
	static public var loader : hxd.res.Loader;

	public static function init() {
		fs = new hxd.fs.LocalFileSystem(RES, "");
		loader = new hxd.res.Loader(fs);
	}
	#end
}