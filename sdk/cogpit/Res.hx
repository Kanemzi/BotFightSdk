package cogpit;

#if !macro
@:build(hxd.res.FileTree.build("sdk/cogpit/res", "cogpit"))
#end
class Res {
	static var RES = "sdk/cogpit/res";

	#if !macro
	static public var fs : hxd.fs.FileSystem;
	static public var loader : hxd.res.Loader;

	public static function init() {
		fs = new hxd.fs.LocalFileSystem(RES, "");
		loader = new hxd.res.Loader(fs);
		hxd.res.Loader.currentInstance = loader; // @todo temporary, games need an instance too
	}
	#end
}