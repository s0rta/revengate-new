extends Object

## Aliases to make the creation of vectors slightly less verbose.
class_name V

static func i(x, y=null) -> Vector2i:
	if y == null: 
		assert(x is Array and x.length() == 2, \
				"Make sure we received a pair of coordinates in the first arg.")
		y = x[1]
		x = x[0]
	return Vector2i(x, y)
