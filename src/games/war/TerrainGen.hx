package games.war;

import hxd.Rand;
import haxe.EnumFlags;
import games.war.WarState.Vec;

enum SymKind {
    Point;
    Axe(both : Bool);
}

typedef Sym = {
    var c : Vec;
    var k : SymKind;
}


class TerrainGen {
    inline static final BOTH_SYM_PROBA = 0.2;

    public static function randSym(cx : Float, cy : Float, rnd : hxd.Rand) : Sym {
        final n = rnd.rand();
        final k = (n < (1.0 - BOTH_SYM_PROBA) / 2.0) ? Point : Axe(n > 1.0 - BOTH_SYM_PROBA);  
        return {c : new Vec(cx, cy), k : k};
    }

    public static inline function iterSym(sym : Sym, x : Float, y : Float, f : (Float, Float) -> Void) {
        final xs = sym.c.x * 2. - x;
        final ys = sym.c.y * 2. - y;
        f(x, y);
        switch (sym.k) {
            case Point:
                f(xs, ys);
            case Axe(both):
                f(xs, y);
                if (both) {
                    f(x, ys);
                    f(xs, ys);
                }
        }
    } 
}