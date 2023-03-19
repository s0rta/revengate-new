# Copyright © 2023 Yannick Gingras <ygingras@ygingras.net> and contributors

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

## Factories to fill areas of boards with mazes.
class_name Mazes extends RefCounted

class MazeBuilder extends RefCounted:
	## Base class for MazeBuilders, specific algorithem must be implemented in `fill()`
	var builder: BoardBuilder
	var rect: Rect2i

	func _init(builder_, rect_=null, even_align=true):
		## even_align: align the grid to make supercells have their coordinate on 
		#    even numbered tiles.
		builder = builder_
		if rect_:
			rect = rect_
		else:
			rect = builder.rect
		
		if even_align:
			_align_rect()
		# Make sure we don't attempt to fill partial supercells
		rect.size -= rect.size % 2

	func _align_rect():
		## Make sure our rect aligns to make every supercells anchored on an even coord
		var offset = rect.position % 2
		rect.position += offset
		rect.size -= offset
		
	func iter_sc_coords(visitor:Callable):
		## Call visitor() with every super cell coordinate.
		var start = rect.position
		var end = rect.end
		for i in range(start.x, end.x, 2):
			for j in range(start.y, end.y, 2):
				var sc_coord = V.i(i, j)
				visitor.call(sc_coord)

	func get_supercells():
		## Return an Array of all the supercells that are accesscible from this MazeCreator
		var sc_coords = []
		var start = rect.position
		var end = rect.end
		for i in range(start.x, end.x, 2):
			for j in range(start.y, end.y, 2):
				sc_coords.append(Vector2i(i, j))
		return sc_coords

	func sc_coords_str(supercells):
		## Return a string representation of an Array of supercells coordinates.
		var coord_strs = []
		for coord in supercells:
			coord_strs.append(RevBoard.supercell_str(coord))
		return "[%s]" % [", ".join(coord_strs)]

	func rand_supercell():
		## Return a random supercell inside our `rect`
		var dx = randi() % rect.size.x / 2
		var dy = randi() % rect.size.y / 2
		return rect.position + Vector2i(dx*2, dy*2)

	func adj_supercells(sc_coord):
		var adjs = []
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT, Vector2i.LEFT]:
			var coord = sc_coord + dir*2
			if rect.has_point(coord):
				adjs.append(coord)
		return adjs

	func fill(coord=null):
		## Fill our `rect` with a maze pattern.
		## Must be overloaded by base classes.
		assert(false, "Not implemented")


# http://weblog.jamisbuck.org/2010/12/27/maze-generation-recursive-backtracking
class RecursiveBacktracker extends MazeBuilder:
	var seen: Dictionary

	func _fill(coord:Vector2i):
		# recursive case of the algorithm
		if seen.get(coord):
			return
		
		builder.paint_cells([coord], "floor")
		seen[coord] = true
		
		var adjs = adj_supercells(coord)
		adjs.shuffle()
		for adj in adjs:
			if not seen.get(adj):
				_fill(adj)
				var joint = (coord + adj) / 2
				builder.paint_cells([joint], "floor")

	func fill(coord=null):
		# start of the algo, init state then start recursing
		seen = {}
		if coord == null:
			coord = rand_supercell()
		_fill(coord)		
