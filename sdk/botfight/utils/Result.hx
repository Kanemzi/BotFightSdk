package botfight.utils;

enum Result<T, E> {
	Ok(r : T);
	Error(e : E);
}