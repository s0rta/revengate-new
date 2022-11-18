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


static func rect_perim(rect: Rect2i) -> Array:
	## Return all the coordinates making the inner perimeter of a rectangle.
	## The coordinates are returned clockfise starting at rect.position.
	var coords = []
	for i in range(rect.size.x):
		coords.append(rect.position + V.i(i, 0))
	for j in range(1, rect.size.y):
		coords.append(rect.position + V.i(rect.size.x-1, j))
	for i in range(rect.size.x-2, 0, -1):
		coords.append(rect.position + V.i(i, rect.size.y-1))
	for j in range(rect.size.y-1, 0, -1):
		coords.append(rect.position + V.i(0, j))
	return coords
	
