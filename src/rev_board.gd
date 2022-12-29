# Copyright © 2022 Yannick Gingras <ygingras@ygingras.net> and contributors

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

extends TileMap
class_name RevBoard

const TILE_SIZE = 32

# which terrains do we index for later retrieval?
const INDEXED_TERRAINS = ["stairs-down", "stairs-up"]

# approximate topological distance to the starting board, used for spawning difficulty
var depth := 0  
var connector_by_coord := {}  # (x, y) -> {far_board:_, far_coord:_}
var _cells_by_terrain := {}  # terrain_name -> array of coords

## PriorityQueue based on distance: dequeing is always with the 
## smallest value.
class DistQueue extends PriorityQueue:
	static func inverse(value):
		## Return the negative of a value. 
		## If value is an Array, return an Array of the negatives if the Array items.
		if value is Array:
			var inv = []
			for item in value:
				inv.append(-item)
			return inv
		else:
			return -value
	
	func _to_string():
		return "<DistQueue %s>" % [heap]
		
	func enqueue(item, dist):
		# var pri = inverse(dist)
		super.enqueue(item, dist)
		
	func peek():
		## Return the distance of the next item to be dequeued.
		var rec = heap[0]
		# return inverse(rec[PriorityQueue.PRIORITY_FIELD])
		return rec[PriorityQueue.PRIORITY_FIELD]

class Matrix:
	var size: Vector2i 
	var cells: Array
	
	func _init(mat_size, default=null):
		if mat_size is Array:
			mat_size = Vector2i(mat_size[0], mat_size[1])
		size = mat_size
		cells = []
		cells.resize(size.y)
		for j in range(size.y):
			cells[j] = []
			cells[j].resize(size.x)
			cells[j].fill(default)
	
	func getv(pos:Vector2i):
		return cells[pos.y][pos.x]
	
	func setv(pos:Vector2i, val):
		cells[pos.y][pos.x] = val

	func _to_string():
		var str = ""
		var row = ""
		var prefix = "["
		var suffix = ""
		for j in range(size.y):
			if j < size.y - 1:
				suffix = ","
			else:
				suffix = "]"
			row = prefix + "["
			for i in range(size.x):
				row += str(cells[j][i])
				if  i != size.x - 1:
					row += ", "
			row += "]" + suffix + "\n"
			str += row
			prefix = " "
		return str
		
	func pad(width=null):
		## Pad all entries to make them `width` long char fields.
		## `width`: match the widest field if not provided
		if width == null:
			width = 0
			var str = ""
			for i in range(size.x):
				for j in range(size.y):
					if cells[j][i] is String:
						str = cells[j][i]
					else:
						str = "%s" % cells[j][i]
					if str.length() > width:
						width = str.length()

		for i in range(size.x):
			for j in range(size.y):
				cells[j][i] = "%*s" % [width, cells[j][i]]						
		
	func duplicate():
		var mat = Matrix.new(size)
		for j in range(size.y):
			mat.cells[j] = Array(cells[j])
		return mat
		
	func replace(old_val, new_val):
		for i in range(size.x):
			for j in range(size.y):
				var pos = Vector2i(i, j)
				if getv(pos) == old_val:
					setv(pos, new_val)
		
class BoardMetrics:
	var start: Vector2i
	var dest
	var dists: Matrix
	var furthest_coord = start
	var furthest_dist = 0
	var prevs = {}
	
	func _init(size:Vector2i, start_:Vector2i, dest_=null):
		start = start_
		dest = dest_
		dists = Matrix.new(size)
		dists.setv(start, 0)
		furthest_coord = start
		prevs[start] = null

	func _to_string():
		var mat = dists.duplicate()
		mat.replace(null, "")
		mat.pad()
		return mat.to_string()

	func getv(coord:Vector2i):
		return dists.getv(coord)
	
	func setv(coord:Vector2i, val):
		if val > furthest_dist:
			furthest_coord = coord
			furthest_dist = val
		dists.setv(coord, val)
	
	func add_edge(here, there):
		## record that `here` is the optimal previous location to reach `there`.
		## The caller is responsible for knowing that the edge is indeed optimal.
		prevs[there] = here

	func path(to=null):
		## Return an Array of coordinates going from `self.start` to `to`.
		## Use `self.dest` if `to` is not provided.
		## `start` and `to` are included in the array.
		var dest
		if to == null:
			assert(self.dest != null, \
					"Make sure we were originally passed a destination.")
			dest = self.dest
		else:
			dest = to
		var path = []
		var current = dest
		while current != null:
			path.append(current)
			current = prevs.get(current)
		if path[-1] != start:
			return null
		else:
			path.reverse()
			return path


class TileSpiral extends RefCounted:
	var board: RevBoard
	var center: Vector2i
	var free: bool
	var in_board: bool
	var bbox
	var coords_index
	var coords
	var radius
	var max_radius
	var board_index
	var is_init: bool = false
	
	static func get_max_radius(center: Vector2i, bbox: Rect2i):
		## Return the largest radius that a spiral can grow to before only 
		## producing coords outside the bounding box.
		var v1 = center - bbox.position
		var v2 = bbox.end - center - Vector2i.ONE
		return max(v1.x, v1.y, v2.x, v2.y)

	func _init(board_, center_, max_radius_=null, free_:bool=true, in_board_:bool=true, 
				bbox_=null, board_index_=null):
		## max_radius: how far from center to consider coordiates, infered from 
		##  the bounding box if not provided.
		## all other params: like RevBoard.ring()
		board = board_
		center = center_
		free = free_
		in_board = in_board_
		board_index = board_index_
		if free and not board_index:
			board_index = board.make_index()
		if bbox_ != null:
			bbox = bbox
		else:
			bbox = board.get_used_rect()
		if max_radius_ != null:
			max_radius = max_radius_
		else:
			max_radius = get_max_radius(center, bbox)
		
	func _iter_init(_arg):
		radius = 0
		is_init = true
		return grow_radius()
		
	func _iter_next(_arg):
		coords_index += 1
		if coords_index < coords.size():
			return true
		else:
			return grow_radius()
		
	func _iter_get(_arg):
		return coords[coords_index]

	func next():
		## Advance the iterator and return the next element.
		## Return null if the iteration is over.
		if not is_init:
			if not _iter_init(null):
				return null
		elif not _iter_next(null):
			return null
		return _iter_get(null)

	func grow_radius():
		## Increase the spiral to the next size up if possible.
		## Return whether there are still coodinates to generate.
		radius += 1
		coords_index = 0
		if radius > max_radius:
			coords = []
			return false
		
		coords = board.ring(center, radius, free, in_board, bbox, board_index)
		if coords.size():
			return true
		else:
			return grow_radius()
			
	func _to_string():
		var cells = []
		for c in self:
			cells.append(c)
		_iter_init(null)
		return "%s" % [cells]

class BoardIndex extends RefCounted:
	## A lookup helper for game items that are on the board
	var board: RevBoard

	var _coord_to_actor := {}
	var _actor_to_coord := {}

	func _init(board_, actors):
		board = board_
		for actor in actors:
			add_actor(actor)

	func has_actor(actor:Actor):
		return _actor_to_coord.has(actor)

	func get_actors():
		return _actor_to_coord.keys()

	func add_actor(actor:Actor):
		var coord = actor.get_cell_coord()
		_coord_to_actor[coord] = actor
		_actor_to_coord[actor] = coord
		
	func remove_actor(actor:Actor):
		var coord = _actor_to_coord[actor]
		_actor_to_coord.erase(actor)
		_coord_to_actor.erase(coord)

	func refresh_actor(actor:Actor, strict:=true):
		## Refresh the coordiates of `actor` in the index.
		## strict: fail if `actor` is not already in the index.
		if not has_actor(actor):
			if strict:
				assert(false, "Can't refresh actor that is not already part of the index")
			else:
				return add_actor(actor)
		var old_coord = _actor_to_coord[actor]
		var new_coord = actor.get_cell_coord()
		_coord_to_actor.erase(old_coord)
		_coord_to_actor[new_coord] = actor
		_actor_to_coord[actor] = new_coord

	func is_occupied(coord):
		if _coord_to_actor.has(coord):
			return true
		return false

	func is_free(coord):
		## Return whether a cell is both walkable and unoccuppied.
		return board.is_walkable(coord) and not is_occupied(coord)

	func actor_at(coord:Vector2i):
		## Return the actor occupying `coord` or null if there is no one there.
		if _coord_to_actor.has(coord):
			return _coord_to_actor[coord]
		else:
			return null

	func actor_foes(me: Actor, max_dist=null):
		## Return an array of actors for whom `me` has negative sentiment.
		## max_dist: in board board tiles
		var foes = []
		var my_coord = me.get_cell_coord()
		var foe_coord = null
		for actor in _actor_to_coord:
			if actor == me:
				continue
			foe_coord = actor.get_cell_coord()
			if max_dist and board.dist(my_coord, foe_coord) > max_dist:
				continue
			if me.is_foe(actor):
				foes.append(actor)
		return foes

static func canvas_to_board(cpos):
	## Return a coordinate in number of tiles from coord in pixels.
	return Vector2i(int(cpos.x) / TILE_SIZE,
					int(cpos.y) / TILE_SIZE)

static func board_to_canvas(coord):
	## Return a coordinate in pixels to the center of the tile at coord. 
	var half_tile = TILE_SIZE / 2
	return Vector2(coord.x * TILE_SIZE + half_tile, 
					coord.y * TILE_SIZE + half_tile)

func set_active(active:=true):
	## Make the board active: visible and collidable)
	visible = active
	set_layer_enabled(0, active)

func make_index():
	var actors = get_actors()
	return BoardIndex.new(self, actors)

func _append_terrain_cells(cells, terrain_name):
	assert(terrain_name in INDEXED_TERRAINS)
	if terrain_name not in _cells_by_terrain:
		_cells_by_terrain[terrain_name] = []
	_cells_by_terrain[terrain_name] += cells

func get_cells_by_terrain(terrain_name):
	## Return all known cells of terrain_name.
	## Cells matching the terrain will be unknown if they have been painted 
	## outside the Builder or if they are not of a terrain in INDEXED_TERRAINS.
	if terrain_name in _cells_by_terrain:
		return _cells_by_terrain[terrain_name]
	else:
		return []

func get_cell_by_terrain(terrain_name):
	## return an arbitrary cell of terrain_name or null if none is known
	var cells = get_cells_by_terrain(terrain_name)
	if not cells.is_empty():
		return cells[0]
	else:
		return null

func add_connection(near_coord, far_board, far_coord):
	## Connect this board with another one.
	## Connections has a near (self) and a far side (far_board). This method makes the
	## connection bi-directional.
	# TODO: connect the path, not the board, since that will serialize better
	connector_by_coord[near_coord] = {"far_board": far_board, "far_coord": far_coord}
	far_board.connector_by_coord[far_coord] = {"far_board": self, "far_coord": near_coord}

func get_connection(coord:Vector2i):
	## Return the far-side data of a cross-board connection
	if connector_by_coord.has(coord):
		return connector_by_coord[coord]
	else:
		return null

func is_connector(coord:Vector2i):
	## Return whether `coord` is a tile that can connect to a different board.
	var data = get_cell_tile_data(0, coord)
	return 	data.get_custom_data("is_connector")

func is_walkable(coord:Vector2i):
	## Return whether a cell is walkable for normal actors
	# collision is only specified on physics layer 0
	var tdata = get_cell_tile_data(0, coord)
	assert(tdata != null, "no data for coord=%s" % coord)
	var poly = tdata.get_collision_polygons_count(0)
	return poly == 0

func ring(center:Vector2i, radius:int, free:bool=true, in_board:bool=true, bbox=null, index=null):
	## Return an Array of coords that define a Chebyshev-ring around `center`.
	## In other words, the coords are arranged like a square on the game board 
	## and they all have the same board.dist() metric to `center`.
	## see filter_coords() for the description of the other params	
	var coords = []
	var r = radius

	for i in range(-r, r+1):
		coords.append(center + V.i(i, -r))
	for j in range(-r+1, r+1, 1):
		coords.append(center + V.i(r, j))
	for i in range(r-1, -r-1, -1):
		coords.append(center + V.i(i, r))
	for j in range(r-1, -r, -1):
		coords.append(center + V.i(-r, j))
	return filter_coords(coords, free, in_board, bbox, index)
	
func spiral(center:Vector2i, max_radius=null, free:bool=true, in_board:bool=true, 
			bbox=null, index=null):
	## Return an iterator of coordiates describing progressively larger rings around `center`.
	## max_radius: how far from center to consider coordiates, infered from 
	##  the bounding box if not provided.
	## all other params: like RevBoard.filter_coords()
	return RevBoard.TileSpiral.new(self, center, max_radius, free, in_board, bbox, index)

func adjacents(pos:Vector2i, free:bool=true, in_board:bool=true, 
				bbox=null, index=null):
	## Return an Array of coords immediately next to `pos`. 
	## see filter_coords() for the description of the other params
	# This is a special case of ring()
	var coords = []
	for i in [-1, 0, 1]:
		coords.append(pos + Vector2i(i, -1))
	for j in [0, 1]:
		coords.append(pos + Vector2i(1, j))
	for i in [0, -1]:
		coords.append(pos + Vector2i(i, 1))
	for j in [0]:
		coords.append(pos + Vector2i(-1, j))
		
	return filter_coords(coords, free, in_board, bbox, index)

func filter_coords(coords, free, in_board, bbox, index=null):
	## Return a sub-selection of coords that match criteria for being walkable 
	## and contained within the bounding box `bbox`.
	## free: only include tiles that are walkable and unoccupied
	## in_board: only include tiles that are inside the board (edges included)
	## index: optionnal BoardIndex with extra information on walkability
	# TODO: support `filter_pred`
	if in_board:
		if bbox == null:
			bbox = get_used_rect()
		# The doc says that the right and bottom edges are excluded, but this 
		# actally works just fine because they assume a different semantic for 
		# bottom-right (rect.end()) that is [1, 1] away from our tile-based 
		# definition. 
		coords = coords.filter(func (coord): return bbox.has_point(coord))
	if free:
		if index != null:
			assert(index is BoardIndex)
			coords = coords.filter(index.is_free)
		else:
			coords = coords.filter(is_walkable)
	return coords

func get_used_rect() -> Rect2i:
	var bbox:Rect2i = super.get_used_rect()
	assert(bbox.position == Vector2i.ZERO, \
			"make sure the board starts at the origin")
	return bbox


static func dist(from, to):
	## Return the distance between two tiles in number of moves.
	## Obstacles are not taken into account, use path() for that.
	## This is also known at the Chebyshev distance.
	return max(abs(from.x - to.x), abs(from.y - to.y))

static func man_dist(from, to):
	## Return the Manhattan distance between to and from.
	return abs(from.x - to.x) + abs(from.y - to.y)

func astar_metrics(start, dest, max_dist=null):
	## Return sparse BoardMetrics using the A* algorithm. 
	## If max_dist is provided, only explore until max_dist depth is reached 
	## and return partial metrics.
	# find our size
	var bbox:Rect2i = get_used_rect()
	var index = make_index()
	if dest:
		assert(is_walkable(Vector2i(dest.x, dest.y)))

	# find the start: randomize if not provided
	if start == null:
		# TODO: pick only walkable starting points
		start = Rand.pos_in_rect(bbox)
	
	var metrics = BoardMetrics.new(bbox.size, start, dest)
	var queue = DistQueue.new()
	var done = {}
	var estimate = dist(start, dest)
	# dist is a [f(n), g(n), man(p, n)] triplets: estimate and real dists
	# with Manhattan distance with the previous node as the tie breaker to favor 
	# straigth lines over diagonals.
	var dist = [estimate, 0, 0]  
	var pre_dist = null   # dist from start to a coord
	var post_dist = null  # dist from a coord to dest
	queue.enqueue(start, dist)
	var current = null
	while not queue.empty():
		dist = queue.peek()
		current = queue.dequeue()
		if current == dest:
			break  # Done!
		elif dist(current, dest) == 1:
			# got next to dest, no need to look at adjacents()
			metrics.setv(dest, dist[1]+1)
			metrics.add_edge(current, dest)
			break
		if done.has(current) or dist[1] == max_dist:
			continue  # this position is finalized already

		for pos in adjacents(current, true, true, bbox, index):
			if done.has(pos):
				continue
			pre_dist = metrics.getv(pos)
			if pre_dist == null or pre_dist > dist[1]+1:
				metrics.setv(pos, dist[1]+1)
				metrics.add_edge(current, pos)
			post_dist = dist(pos, dest)
			estimate = post_dist + dist[1] + 1
			queue.enqueue(pos, [estimate, dist[1]+1, man_dist(pos, current)])
		done[current] = true
	return metrics
	

func dist_metrics(start=null, dest=null, max_dist=null):
	## Return distance metrics or all positions accessible from start. 
	## Start is randomly selected if not provided.
	## Stop exploring after reaching `dest` if provided.
	## Do not explore further than `max_dist` if provided. 
	# using the Dijkstra algo
	
	# find our size
	var bbox:Rect2i = get_used_rect()
	var index = make_index()
	if dest:
		assert(is_walkable(Vector2i(dest.x, dest.y)))
			
	# find the start: randomize if not provided
	if start == null:
		# TODO: pick only walkable starting points
		start = Rand.pos_in_rect(bbox)
	
	var metrics = BoardMetrics.new(bbox.size, start, dest)
	var queue = DistQueue.new()
	var done = {}
	var dist = 0
	var pre_dist = null  # dist from start to a coord
	queue.enqueue(start, dist)
	var current = null
	while not queue.empty():
		dist = queue.peek()
		current = queue.dequeue()
		if current == dest:
			break  # Done!
		elif dest != null and dist(current, dest) == 1:
			# got next to dest, no need to look at adjacents()
			metrics.setv(V.i(dest.x, dest.y), dist+1)
			metrics.add_edge(current, dest)
			break
		if done.has(current) or dist == max_dist:
			continue  # this position is finalized already

		for pos in adjacents(current, true, true, bbox, index):
			if done.has(pos):
				continue
			pre_dist = metrics.getv(pos)
			if pre_dist == null or pre_dist > dist+1:
				metrics.setv(pos, dist+1)
				metrics.add_edge(current, pos)
			queue.enqueue(pos, dist+1)
		done[current] = true
	return metrics
	
func path(start, dest, max_dist=null):
	## Return an Array of coordinates from `start` to `dest`.
	## See BoardMetrics.path() for more details.
	var metrics = astar_metrics(start, dest, max_dist)
	return metrics.path()

func get_actors():
	## Return an array of actors presently on this board.
	var actors = []
	for node in get_children():
		if node is Actor:
			actors.append(node)
	return actors