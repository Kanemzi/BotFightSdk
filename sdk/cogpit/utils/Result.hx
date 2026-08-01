package cogpit.utils;

enum Result<T, E> {
	Ok(r : T);
	Error(e : E);
}