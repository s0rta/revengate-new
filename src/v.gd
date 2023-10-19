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

static func arr_i(pairs:Array[Array]) -> Array[Vector2i]:
	var vects:Array[Vector2i] = []
	for pair in pairs:
		vects.append(Vector2i(pair[0], pair[1]))
	return vects
