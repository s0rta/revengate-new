# Copyright © 2023–2024 Yannick Gingras <ygingras@ygingras.net> and contributors

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

const CROSS_DIRS = Geom.CROSS_OFFSETS

class MazeBuilder extends RefCounted:
	## Base class for MazeBuilders, specific algorithem must be implemented in `fill()`
	var builder: BoardBuilder
	var rect: Rect2i
	var mask = null

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

	func _align_rect():
		## Make sure our rect aligns to make every supercells anchored on an even coord
		var offset = rect.position % 2
		rect.position += offset
		rect.size -= offset
	
	func effective_rect():
		## Return the rect that will/have-been be filled by the maze. 
		## The difference between this and the rect passed to the constructor is due to 
		## grid alignment and the unavoidable parital filling of supercells around the bottom
		## and right edges.
		var erect = Rect2i(rect)
		erect.size = erect.size + erect.size % 2 - Vector2i.ONE
		return erect.size
	
	func set_mask(mask_):
		mask = mask_
	
	func iter_sc_coords(visitor:Callable):
		## Call visitor() with every super cell coordinate.
		var start = rect.position
		var end = rect.end
		for i in range(start.x, end.x, 2):
			for j in range(start.y, end.y, 2):
				var sc_coord = Vector2i(i, j)
				if mask and mask.has_supercell(sc_coord):
					continue
				visitor.call(sc_coord)

	func get_supercells():
		## Return an Array of all the supercells that are accesscible from this MazeCreator
		var sc_coords = []
		var start = rect.position
		var end = rect.end
		for i in range(start.x, end.x, 2):
			for j in range(start.y, end.y, 2):
				var sc_coord = Vector2i(i, j)
				if mask and mask.has_supercell(sc_coord):
					continue
				sc_coords.append(sc_coord)
		return sc_coords

	func sc_coords_str(supercells):
		## Return a string representation of an Array of supercells coordinates.
		var coord_strs = []
		for coord in supercells:
			coord_strs.append(RevBoard.supercell_str(coord))
		return "[%s]" % [", ".join(coord_strs)]

	func rand_supercell():
		## Return a random supercell inside our `rect`
		## Return null if no suitable supercell can be found
		var dx = randi() % rect.size.x / 2
		var dy = randi() % rect.size.y / 2
		var grid_offset = rect.position % 2
		var supercell = rect.position + Vector2i(dx*2, dy*2)
		if mask and mask.has_supercell(supercell):
			# if we clash with the mask, we try to find the closest cell that is 
			# outside of the mask and match the supercell grid
			var spiral = builder.board.spiral(supercell, null, false, true, rect)
			var coord = spiral.next()
			while coord and (coord%2 != grid_offset or mask.has_supercell(coord)):
				coord = spiral.next()
			return coord
		return supercell

	func adj_supercells(sc_coord):
		var adjs = []
		for dir in CROSS_DIRS:
			var coord = sc_coord + dir*2
			if not rect.has_point(coord):
				continue
			if mask and mask.has_supercell(coord):
				continue
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
		
		builder.board.paint_cell(coord, builder.floor_terrain)
		seen[coord] = true
		
		var adjs = adj_supercells(coord)
		adjs.shuffle()
		for adj in adjs:
			if not seen.get(adj):
				_fill(adj)
				var joint = (coord + adj) / 2
				builder.board.paint_cell(joint, builder.floor_terrain)

	func fill(coord=null):
		# start of the algo, init state then start recursing
		seen = {}
		if coord == null:
			coord = rand_supercell()
		_fill(coord)		


# https://weblog.jamisbuck.org/2011/1/27/maze-generation-growing-tree-algorithm
class GrowingTree extends MazeBuilder:
	const DEF_BIASES = {"branching"=0.0, "reconnect"=0.0, "twistiness"=0.5}
	var seen: Dictionary
	var stack: Array[Vector2i]
	var finalized: Dictionary
	var biases: Dictionary

	func _init(builder_, biases_={}, rect_=null, even_align=true):
		super(builder_, rect_, even_align)
		
		# make sure biases are sensible
		for key in biases_.keys():
			assert(DEF_BIASES.has(key), "%s is not a known bias key" % key)
		if biases_.has("twistiness"):
			assert(0<=biases_["twistiness"] and biases_["twistiness"]<=1, 
				"Twistiness must be in [0.0 .. 1.0]")
		biases = biases_
	
	func get_bias(key):
		var val = biases.get(key)
		if val == null:
			val = DEF_BIASES[key]
		return val
		
	func bias_test(key):
		## Return if a bias is currently active.
		return Rand.rstest(get_bias(key))
	
	func _trim_stack():
		## Remove finalized nodes from the top of the stack
		while not stack.is_empty() and finalized.get(stack[-1]):
			stack.pop_back()
	
	func last_grow_point():
		_trim_stack()
		if not stack.is_empty():
			return stack[-1]
		return null

	func random_grow_point():
		var pos = randi_range(0, stack.size()-1)
		var dir = Rand.choice([-1, 1])
		while not stack.is_empty():
			if not finalized.get(stack[pos]):
				return stack[pos]
			elif pos == -1 or pos == stack.size()-1:
				_trim_stack()
				pos = stack.size()-1
			else:
				pos = (pos + dir) % stack.size()
		return null
	
	func select_grow_point():
		## Return a supercell already in the maze to be the grow point for the next extension.
		## Return `null` if there are no suitable supercells to grow from.
		if bias_test("branching"):
			return random_grow_point()
		else:
			return last_grow_point()
	
	func _is_turn(sc_coord, relative_to):
		# Is sc_coord a turn if we are coming from sc_coord? 
		# It has to be if the joint on the opposite side of relative_to is not walkable.
		var offset = sc_coord - relative_to
		if offset.length() > 1:
			offset /= roundi(offset.length())
		var opposite = relative_to - offset
		if not rect.has_point(opposite):
			return true
		else:
			return not builder.board.is_walkable(opposite)
	
	func select_adj(supercell):
		## Return a neighbors from `supercell`.
		## Return null if there are no suitable neighbors.
		var adjs = []
		var weights = []
		
		# weights should not be 0.0 or we'll incorrectly mark the supercell as done too early
		var twist_weight = 0.001 + get_bias("twistiness")
		var straight_weight = 1.001 - get_bias("twistiness")

		for adj in adj_supercells(supercell):
			if not seen.get(adj):
				adjs.append(adj)
				if _is_turn(adj, supercell):
					weights.append(twist_weight)
				else:
					weights.append(straight_weight)
		if adjs.is_empty():
			return null
		else:
			return Rand.weighted_choice(adjs, weights)
	
	func fill(start=null):
		finalized = {}

		if start == null:
			start = rand_supercell()
		stack = [start]
		seen = {start:true}
		builder.board.paint_cell(start, builder.floor_terrain)

		var done = false
		while not done:
			var grow_point = select_grow_point()
			if grow_point == null:
				done = true
				break
			var adj = select_adj(grow_point)
			if adj == null:
				finalized[grow_point] = true
				if is_mergeable(grow_point) and bias_test("reconnect"):
					merge_at(grow_point)
			else:
				stack.append(adj)
				seen[adj] = true
				var joint = (grow_point + adj) / 2
				builder.board.paint_cells([adj, joint], builder.floor_terrain)
								
	func merge_at(supercell):
		## Merge two corridors at `supercell` by removing the wall at the far side of the dead-end.
		for dir in CROSS_DIRS:
			var cell = supercell + dir
			if builder.board.is_walkable(cell):
				var joint = supercell - dir
				builder.board.paint_cell(joint, builder.floor_terrain)
				break

	func is_mergeable(supercell):
		## Return whether surpercell is a good merge point to rejoin two corridors together. 
		## We only conside dead-ends with a corridor on the other side of the furthest wall. 
		## This configuration always looks good when removing the wall at the end of the dead end. 
		## There are non-dead-end configurations that can look good after removing a wall, but 
		## they are harder to detect so we don't consider them.
		## This only works when the terrain under consideration was all generated by this MazeCreator.
		var nb_walls = 0
		var last_floor: Vector2i
		for dir in CROSS_DIRS:
			var cell = supercell + dir
			if not rect.has_point(cell):
				return false
			var terrain = builder.board.get_cell_terrain(cell)
			var walkable = builder.board.is_walkable(cell)
			if walkable:
				last_floor = cell
			else:
				nb_walls += 1
		if nb_walls == 3:
			var offset = supercell - last_floor 
			var other_side = supercell + offset * 2
			return rect.has_point(other_side) and builder.board.is_walkable(other_side)
		else:
			return false

class Mask extends RefCounted:
	## A region that should not be filled with the maze. Anchors are relative to the board, 
	## not to MazeCreator.rect.
	var next: Mask
	
	func chain_with(mask:Mask):
		## Combine a secondary mask with this one.
		assert(mask != self, "mask cannot be chainned with itself")
		if next:
			next.chain_with(mask)
		else:
			next = mask
	
	func has_point(coord:Vector2i):
		if next:
			return next.has_point(coord)
		else:
			return false
		
	func intersects(region:Rect2i):
		if next:
			return next.intersects(region)
		else:
			return false

	func has_supercell(supercell:Vector2i):
		return intersects(Rect2i(supercell, Vector2i(2, 2)))

class RectMask extends Mask:
	var rect: Rect2i
	
	func _init(rect_:Rect2i):
		rect = rect_
		
	func has_point(coord:Vector2i):
		if rect.has_point(coord):
			return true
		else:
			return super(coord)
		
	func intersects(region:Rect2i):
		if rect.intersects(region):
			return true
		else:
			return super(region)
