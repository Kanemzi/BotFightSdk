package utils;

#if !macro

import hl.Gc;
import haxe.io.BytesBuffer;
import haxe.io.Eof;

class Extensions {

	/**
		Thread safe blocking readline function.
		Based on the implementation from haxe.io.Input.readLine().

		Read a line of text separated by CR and/or LF bytes.
		The CR/LF characters are not included in the resulting string.
	*/
	public static function safeReadLine(input : haxe.io.Input) : String {
		var buf = new BytesBuffer();
		var last : Int;
		var s : String;
		try {
			while (true) {
				Gc.blocking(true);
				last = input.readByte();
				Gc.blocking(false);

				if (last == 10) break;
				buf.addByte(last);
			}
			s = buf.getBytes().toString();
			if (s.charCodeAt(s.length - 1) == 13)
				s = s.substr(0, -1);
		} catch (e : Eof) {
			s = buf.getBytes().toString();
			if (s.length == 0)
				throw e;
		}
		return s;
	}
}

#end