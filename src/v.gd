# Copyright © 2022-2023 Yannick Gingras <ygingras@ygingras.net> and contributors

# This file is part of Revengate.

# Revengate is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Revengate is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with Revengate.  If not, see <https://www.gnu.org/licenses/>.

## Aliases to make the creation of vectors slightly less verbose.
class_name V extends Object

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
	
