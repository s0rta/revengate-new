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

class_name RevBoard extends TileMap

const TILE_SIZE = 32

# which terrains lead to other boards?
const CONNECTOR_TERRAINS = ["stairs-down", "stairs-up", "gateway"]
# which terrains do we index for later retrieval?
const INDEXED_TERRAINS = CONNECTOR_TERRAINS
# plain floor without other features
const FLOOR_TERRAINS = ["floor", "floor-rough", "floor-dirt"]

signal new_message(message)

# approximate topological distance to the starting board, used for spawning difficulty
var depth := 0  

var world_loc: Vector3i  # relative positioning of this board in the world

# per-cell custom data, unlike the per-tile data provided by TileMap
var _cell_records := {}  # (x, y) -> {'rec_name' -> {...}}

var _cells_by_terrain := {}  # terrain_name -> array of coords
var current_turn := 0


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
	
	func all_coords():
		## Return an array of all non-null-weight coordinates
		## 0-dist(s) is included
		var coords = []
		for i in range(dists.size.x):
			for j in range(dists.size.y):
				var coord = V.i(i, j)
				if dists.getv(coord) != null:
					coords.append(coord)
		return coords

	func all_dists():
		## Return an array of all non-null distances in the same order as all_coords()
		var used_dists = []
		for i in range(dists.size.x):
			for j in range(dists.size.y):
				var coord = V.i(i, j)
				var dist = dists.getv(coord)
				if dist != null:
					used_dists.append(dist)
		return used_dists

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

	func ddump_path(to=null):
		var mat = dists.duplicate()
		mat.replace(null, "")
		mat.pad()
		var path_steps = path(to)
		for step in path_steps:
			mat.setv(step, Utils.colored(mat.getv(step)))
		print(mat.to_string())

## Optionally used to produce the intermediate values of a BoardMetrics
class MetricsPump:
	var board
	
	func _init(board_):
		board = board_
	
	func dist_real(here, there):
		assert(false, "not implemented")

	func dist_estim(here, there):
		assert(false, "not implemented")

	func dist_tiebreak(here, there):
		assert(false, "not implemented")

## Implement the metrics used for the movement of most actors
class StandardMetricsPump extends MetricsPump:
	func dist_real(here, there):
		return board.dist(here, there)

	func dist_estim(here, there):
		return board.dist(here, there)
		
	func dist_tiebreak(here, there):
		return board.man_dist(here, there)

## Implement metrics that favor following the edge of walls
class WallHugMetricsPump extends MetricsPump:
	var wall_counts: Matrix  # number of walls are in man_dist()=1 for a given coord
	
	func _init(board_):
		super(board_)
		wall_counts = Matrix.new(board.get_used_rect().size)

	func dist_real(here, there):
		# Using Manhattan dist to discourage diagonals, they are still legal but cost +1.
		# It's also more expensive to go where there are fewer walls, up to a certain point.
		return board.man_dist(here, there) + max(0, 2-get_wall_counts(there))

	func dist_estim(here, there):
		return board.man_dist(here, there)
		
	func dist_tiebreak(here, there):
		return 0

	func get_wall_counts(coord) -> int:
		## lazy compute the values when requested
		var val = wall_counts.getv(coord)
		if val == null:
			val = 0
			for offset in [V.i(-1, 0), V.i(0, -1), V.i(1, 0), V.i(0, 1)]:
				if not board.is_walkable(coord+offset):
					val += 1
			wall_counts.setv(coord, val)
		return val

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
			bbox = bbox_
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
	
	# items can be stacked, so we store them in an array
	# the top of the stack it at the end (inder=-1)
	var _coord_to_items := {}  # [x:y] -> Array
	var _item_to_coord := {}

	var _los := {}  # [from, to] -> [[x1:y1], ..., [xn:yn]]

	func _init(board_, actors, items=[]):
		board = board_
		for actor in actors:
			add_actor(actor)
		for item in items:
			add_item(item)

	func has_actor(actor):
		return _actor_to_coord.has(actor)

	func get_actors():
		return _actor_to_coord.keys()
	
	func get_actors_around(coord, radius=1):
		var actors = []
		for actor in get_actors():
			if board.dist(coord, actor.get_cell_coord()) <= radius:
				actors.append(actor)
		return actors

	func get_actors_around_me(me:Actor, radius=1):
		var my_coord = me.get_cell_coord()
		var actors = []
		for actor in get_actors():
			if actor != me and board.dist(my_coord, actor.get_cell_coord()) <= radius:
				actors.append(actor)
		return actors
	
	func add_actor(actor):
		var coord = actor.get_cell_coord()
		_coord_to_actor[coord] = actor
		_actor_to_coord[actor] = coord

	func has_item(item):
		return _item_to_coord.has(item)

	func add_item(item):
		var coord = item.get_cell_coord()
		assert(coord, "trying to index an item that is not on the board")
		if not _coord_to_items.has(coord):
			_coord_to_items[coord] = []
		_coord_to_items[coord].append(item)
		_item_to_coord[item] = coord
		
	func remove_actor(actor):
		var coord = _actor_to_coord[actor]
		_actor_to_coord.erase(actor)
		_coord_to_actor.erase(coord)

	func refresh_actor(actor, strict:=true):
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

	func refresh_item(item:Item, strict:=true):
		## Refresh the coordiates of `item` in the index.
		## strict: fail if `item` is not already in the index.
		if not has_item(item):
			if strict:
				assert(false, "Can't refresh item that is not already part of the index")
			else:
				return add_item(item)
		var old_coord = _item_to_coord[item]
		var new_coord = item.get_cell_coord()
		_coord_to_items[old_coord].erase(item)
		if not _coord_to_items.has(new_coord):
			_coord_to_items[new_coord] = []
		_coord_to_items[new_coord].append(item)
		_item_to_coord[item] = new_coord

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
	
	func top_item_at(coord:Vector2i):
		## return item at the top of the stack at `coord` or null if there are no items there.
		if not _coord_to_items.has(coord) or not _coord_to_items[coord].size():
			return null
		return _coord_to_items[coord][-1]
		
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

	func line_of_sight(from, to):
		## Like Board.line_of_sight(), but cached
		if not _los.has([from, to]):
			_los[[from, to]] = board.line_of_sight(from, to)
		return _los[[from, to]]  # could be null

	func has_los(from, to):
		## Return whether there is a line of sight between `from` and `to`
		if _los.has([from, to]):
			return _los[[from, to]] != null
		elif _los.has([to, from]):
			return _los[[to, from]] != null
		else:
			return line_of_sight(from, to) != null

	func get_actors_in_sight(from, max_radius, include_center=false):
		## Return a list of actors that are visible from `from`
		var actors = []
		for coord in _coord_to_actor:
			if board.dist(from, coord) > max_radius:
				continue
			if coord == from and not include_center:
				continue
			if has_los(from, coord):
				actors.append(_coord_to_actor[coord])
		return actors

	func ddump():
		## Print a summary of the index's content.
		print("Indexed element for %s" % self)
		if not _actor_to_coord.size():
			print("  no actors")
		for actor in _actor_to_coord:
			var coord = _actor_to_coord[actor]
			print("  actor %s recorded at %s" % [actor, RevBoard.coord_str(coord)])
		if not _item_to_coord.size():
			print("  no items")
		for coord in _coord_to_items:
			print("  items at %s: %s" % [RevBoard.coord_str(coord), _coord_to_items[coord]])

static func canvas_to_board(cpos):
	## Return a coordinate in number of tiles from coord in pixels.
	return Vector2i(int(cpos.x) / TILE_SIZE,
					int(cpos.y) / TILE_SIZE)

static func board_to_canvas(coord):
	## Return a coordinate in pixels to the center of the tile at coord. 
	var half_tile = TILE_SIZE / 2
	return Vector2(coord.x * TILE_SIZE + half_tile, 
					coord.y * TILE_SIZE + half_tile)

static func world_loc_str(loc:Vector3i):
	## Return a short hand notation of a world location
	return "⟪%s, %s, %s⟫" % [loc.x, loc.y, loc.z]

static func supercell_str(coord:Vector2i):
	## Return a short hand notation of a supercell coord that is different from Vector2i.to_string()
	return "⟦%d¦%d⟧" % [coord.x, coord.y]	

static func coord_str(coord:Vector2i):
	## Return a short hand notation of coord that is different from Vector2i.to_string()
	return "[%d:%d]" % [coord.x, coord.y]	

static func canvas_to_board_str(cpos):
	return coord_str(canvas_to_board(cpos))

func _ready():
	detect_actors()
	reset_items_visibility()

func set_active(active:=true):
	## Make the board active: visible and collidable)
	visible = active
	set_layer_enabled(0, active)
	if active:
		detect_actors()
		reset_items_visibility()

func is_active():
	return visible and is_layer_enabled(0)

func detect_actors():
	## Register all actors currently on the board.
	for actor in get_actors():
		register_actor(actor)

func purge_registrations():
	## Remove all actor registrations
	for actor in get_actors():
		deregister_actor(actor)
	
func register_actor(actor):
	## connect the relevant signals from `actor` so we can keep track of them
	if not actor.moved.is_connected(_on_actor_moved):
		actor.moved.connect(_on_actor_moved)
		var death_handler = _on_actor_died.bind(actor)
		actor.died.connect(death_handler, CONNECT_ONE_SHOT)
	
func deregister_actor(actor):
	## disconnect our connections with `actor`
	if actor.moved.is_connected(_on_actor_moved):
		actor.moved.disconnect(_on_actor_moved)

func start_turn(new_turn:int):
	## Mark the start a new game turn	
	# FIXME: handle sub_nodes dissipating while we do a multi-turn update
	for node in get_children():
		if node.get("start_turn"):
			node.start_turn(new_turn)
		elif node.get("start_new_turn"):
			for i in new_turn - current_turn:
				if node.is_expired():
					break
				node.start_new_turn()
	current_turn = new_turn
	reset_items_visibility()

func make_index():
	var actors = get_actors()
	var items = get_items()
	return BoardIndex.new(self, actors, items)

func get_cell_rec(coord:Vector2i, rec_name):
	## Return the per-cell record `rec_name` for coord
	if _cell_records.has(coord) and _cell_records[coord].has(rec_name):
		return _cell_records[coord][rec_name]
	return null

func get_cell_rec_val(coord:Vector2i, rec_name, key, default=null):
	## Return a specific value form the per-cell record `rec_name` for coord
	if _cell_records.has(coord) and _cell_records[coord].has(rec_name):
		return _cell_records[coord][rec_name].get(key, default)
	return null

func clear_cell_rec(coord:Vector2i, rec_name):
	## Delete the per-cell record `rec_name` for coord
	if _cell_records.has(coord) and _cell_records[coord].has(rec_name):
		_cell_records[coord].erase(rec_name)

func set_cell_rec(coord:Vector2i, rec_name, rec:Dictionary):
	## Set a per-cell record
	if not _cell_records.has(coord):
		_cell_records[coord] = {}
	_cell_records[coord][rec_name] = rec

func set_cell_rec_val(coord:Vector2i, rec_name, key, value):
	## Set a specific value inside a per-cell record
	if not _cell_records.has(coord):
		_cell_records[coord] = {}
	if not _cell_records[coord].has(rec_name):
		_cell_records[coord][rec_name] = {}
	_cell_records[coord][rec_name][key] = value
	
func _append_terrain_cells(cells, terrain_name):
	assert(terrain_name in INDEXED_TERRAINS)
	if terrain_name not in _cells_by_terrain:
		_cells_by_terrain[terrain_name] = []
	_cells_by_terrain[terrain_name] += cells

func scan_terrain():
	## Re-index the terrain of all non-empty cells. 
	## This is only needed for board that are built manually. BoardBuilders do 
	## the indexing automatically when painting cells.
	_cells_by_terrain = {}
	for coord in get_used_cells(0):
		var terrain = get_cell_terrain(coord)
		if terrain in INDEXED_TERRAINS:
			_append_terrain_cells([coord], terrain)

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

func get_cell_terrain(coord):
	var data = get_cell_tile_data(0, coord) as TileData
	return tile_set.get_terrain_name(data.terrain_set, data.terrain)
	
func is_on_board(coord):
	## Return whether the coord is strictly contained inside the game board
	var bbox = get_used_rect()
	return bbox.has_point(coord)

func add_connection(near_coord, far_board, far_coord):
	## Connect this board with another one.
	## Connections has a near (self) and a far side (far_board). This method makes the
	## connection bi-directional.
	## Return the near-side of the connection
	# TODO: connect the resource path, not the board, since that will serialize better
	var near_conn = {"far_board": far_board, "far_coord": far_coord}
	set_cell_rec(near_coord, "connection", near_conn)
	far_board.set_cell_rec(far_coord, "connection", {"far_board": self, "far_coord": near_coord})
	clear_cell_rec(near_coord, "conn_target")
	far_board.clear_cell_rec(far_coord, "conn_target")
	return near_conn

func get_connection(coord:Vector2i):
	## Return the far-side data of a cross-board connection
	return get_cell_rec(coord, "connection")

func get_connectors():
	## Return the an array of coords for all the connectors on this board.
	var coords = []
	for terrain in CONNECTOR_TERRAINS:
		coords += get_cells_by_terrain(terrain)
	return coords
	
func get_connector_for_loc(world_loc:Vector3i):
	## Return the coord of the connector that leads to `world_loc` 
	## or null if no such connector exists.
	for coord in get_connectors():
		var loc = get_cell_rec_val(coord, "conn_target", "world_loc")
		if loc == null:
			loc = get_cell_rec_val(coord, "connection", "far_board").world_loc
		if loc == world_loc:
			return coord
	return null

func get_connector_terrains():
	## Return a list of all connector terrains on this board, duplicates included.
	var terrains = []
	for terrain in CONNECTOR_TERRAINS:
		for i in len(_cells_by_terrain.get(terrain, [])):
			terrains.append(terrain)
	return terrains

func get_neighbors():
	## Return an array of `world_loc` that we should this board will eventually connect to.
	var neighbors = []
	for coord in get_connectors():
		var conn = get_connection(coord)
		if conn != null:
			neighbors.append(conn.far_board.world_loc)
		else:
			neighbors.append(get_cell_rec_val(coord, "conn_target", "world_loc"))
	return neighbors

func get_neighbors_str():
	## Return a string representation of all of our neighbors.
	var parts = []
	for loc in get_neighbors():
		parts.append(world_loc_str(loc))
	return "[%s]" % ", ".join(parts)

func is_connector(coord:Vector2i):
	## Return whether `coord` is a tile that can connect to a different board.
	var terrain = get_cell_terrain(coord)
	return CONNECTOR_TERRAINS.has(terrain) 

func is_floor(coord:Vector2i):
	## Return whether a cell is a plain floor tile (no stairs or doors or anything fancy).
	return get_cell_terrain(coord) in FLOOR_TERRAINS

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

static func dist(from, to):
	## Return the distance between two tiles in number of moves.
	## Obstacles are not taken into account, use path() for that.
	## This is also known at the Chebyshev distance.
	if from is Actor or from is Item:
		from = from.get_cell_coord()
	if to is Actor or to is Item:
		to = to.get_cell_coord()
	return max(abs(from.x - to.x), abs(from.y - to.y))

static func man_dist(from, to):
	## Return the Manhattan distance between to and from.
	return abs(from.x - to.x) + abs(from.y - to.y)

func _init_metric_context(start, dest, free_dest=false, max_dist=null):
	## Initialize a few internal variables that we need for building a BoardMetrics, 
	## no matter which algo is used.
	## `free_dest`: does the destination have to be walkable?
	##   true: ex.: you want to go there;
	##   false: ex.: you want to get close and attack the actor standing there.
	if dest:
		assert(is_walkable(Vector2i(dest.x, dest.y)))

	# find the start: randomize if not provided
	var bbox:Rect2i = get_used_rect()
	var index = make_index()
	if start == null:
		start = Rand.pos_in_rect(bbox)
		if not is_walkable(start):
			start = spiral(start, null, true, true, null, index).next()
			
	var metrics = BoardMetrics.new(bbox.size, start, dest)	
	var invalid_dest = false
	if free_dest and dest!=null:
		invalid_dest = not index.is_free(dest)

	return {"index": index, "bbox": bbox,
			"start": start, "dest": dest, "invalid_dest": invalid_dest,
			"queue": DistQueue.new(), "done": {}, 
			"pre_dist": null,   # dist from start to a coord
			"post_dist": null,  # dist from a coord to dest
			"metrics": metrics}

func astar_metrics(start_, dest_, free_dest_=false, max_dist=null):
	## Return sparse BoardMetrics using the A* algorithm. 
	## If max_dist is provided, only explore until max_dist depth is reached 
	## and return partial metrics.
	var ctx = _init_metric_context(start_, dest_, free_dest_, max_dist)
	if ctx.invalid_dest:
		return ctx.metrics
	var estimate = dist(ctx.start, ctx.dest)
	# dist is a [h(n), g(n), man(p, n)] triplet: estimate and real dists
	# with Manhattan distance with the previous node as the tie breaker to favor 
	# straigth lines over diagonals.
	var dist = [estimate, 0, 0]  
	ctx.queue.enqueue(ctx.start, dist)
	var current = null
	while not ctx.queue.empty():
		dist = ctx.queue.peek()
		current = ctx.queue.dequeue()
		if current == ctx.dest:
			break  # Done!
		elif dist(current, ctx.dest) == 1:
			# got next to dest, no need to look at adjacents()
			ctx.metrics.setv(ctx.dest, dist[1]+1)
			ctx.metrics.add_edge(current, ctx.dest)
			break
		if ctx.done.has(current) or dist[1] == max_dist:
			continue  # this position is finalized already

		for pos in adjacents(current, true, true, ctx.bbox, ctx.index):
			if ctx.done.has(pos):
				continue
			ctx.pre_dist = ctx.metrics.getv(pos)
			if ctx.pre_dist == null or ctx.pre_dist > dist[1]+1:
				ctx.metrics.setv(pos, dist[1]+1)
				ctx.metrics.add_edge(current, pos)
			ctx.post_dist = dist(pos, ctx.dest)
			estimate = ctx.post_dist + dist[1] + 1
			ctx.queue.enqueue(pos, [estimate, dist[1]+1, man_dist(pos, current)])
		ctx.done[current] = true
	return ctx.metrics
	

func astar_metrics_custom(pump:MetricsPump, start_, dest_, free_dest_=false, max_dist=null):
	## Return sparse BoardMetrics using the A* algorithm. 
	## pump: the fully initialized extractor for the intermediate values
	## all other params like `astar_metrics()`
	# find our size
	var ctx = _init_metric_context(start_, dest_, free_dest_, max_dist)
	if ctx.invalid_dest:
		return ctx.metrics
	var estimate = pump.dist_estim(ctx.start, ctx.dest)
	# dist is a [h(n), g(n), tiebreak(p, n)] triplets: estimate and real dists
	# with tiebreaker from the previous node to finely tune biasess.
	var dist = [estimate, 0, 0]
	ctx.queue.enqueue(ctx.start, dist)
	var current = null
	while not ctx.queue.empty():
		dist = ctx.queue.peek()
		current = ctx.queue.dequeue()
		if current == ctx.dest:
			break  # Done!
		elif dist(current, ctx.dest) == 1:
			# Not using pump.dist_real() in the test because we are looking to see if we are 
			# one step away, no matter what value range the pump in using for the distances.

			# Got next to dest, no need to look at adjacents()
			ctx.metrics.setv(ctx.dest, dist[1]+pump.dist_real(current, ctx.dest))
			ctx.metrics.add_edge(current, ctx.dest)
			break
		if ctx.done.has(current) or dist[1] == max_dist:
			continue  # this position is finalized already

		for pos in adjacents(current, true, true, ctx.bbox, ctx.index):
			if ctx.done.has(pos):
				continue
			ctx.pre_dist = ctx.metrics.getv(pos)
			var step_dist = pump.dist_real(current, pos)
			if ctx.pre_dist == null or ctx.pre_dist > dist[1]+step_dist:
				ctx.metrics.setv(pos, dist[1]+step_dist)
				ctx.metrics.add_edge(current, pos)
			ctx.post_dist = pump.dist_estim(pos, ctx.dest)
			estimate = ctx.post_dist + dist[1]+step_dist
			var tiebreak = pump.dist_tiebreak(pos, current)
			ctx.queue.enqueue(pos, [estimate, dist[1]+step_dist, tiebreak])
		ctx.done[current] = true
	return ctx.metrics

func dist_metrics(start_=null, dest_=null, free_dest_=false, max_dist=null):
	## Return distance metrics or all positions accessible from start. 
	## Start is randomly selected if not provided.
	## Stop exploring after reaching `dest` if provided.
	## Do not explore further than `max_dist` if provided. 
	# using the Dijkstra algo
	var ctx = _init_metric_context(start_, dest_, free_dest_, max_dist)
	if ctx.invalid_dest:
		return ctx.metrics
	var dist = 0
	
	ctx.queue.enqueue(ctx.start, dist)
	var current = null
	while not ctx.queue.empty():
		dist = ctx.queue.peek()
		current = ctx.queue.dequeue()
		if current == ctx.dest:
			break  # Done!
		elif ctx.dest != null and dist(current, ctx.dest) == 1:
			# got next to dest, no need to look at adjacents()
			ctx.metrics.setv(V.i(ctx.dest.x, ctx.dest.y), dist+1)
			ctx.metrics.add_edge(current, ctx.dest)
			break
		if ctx.done.has(current) or dist == max_dist:
			continue  # this position is finalized already

		for pos in adjacents(current, true, true, ctx.bbox, ctx.index):
			if ctx.done.has(pos):
				continue
			ctx.pre_dist = ctx.metrics.getv(pos)
			if ctx.pre_dist == null or ctx.pre_dist > dist+1:
				ctx.metrics.setv(pos, dist+1)
				ctx.metrics.add_edge(current, pos)
			ctx.queue.enqueue(pos, dist+1)
		ctx.done[current] = true
	return ctx.metrics

func path(start, dest, free_dest=true, max_dist=null):
	## Return an Array of coordinates from `start` to `dest`.
	## See BoardMetrics.path() for more details.
	## `free_dest`: does the destination have to be walkable?
	##   true: ex.: you want to go there;
	##   false: ex.: you want to get close and attack the actor standing there.
	var metrics = astar_metrics(start, dest, free_dest, max_dist)
	return metrics.path()

func line_of_sight(coord1, coord2):
	## Return an array of coords in the line of sight between coord1 and coord2 
	## or null if the direct path is visibly obstructed.
	## Both end point params are included in the returned array.
	var steps = []
	var nb_steps = dist(coord1, coord2) + 1
	var mult = max(1, nb_steps - 1)
	# move to continuous coords from the center of the tiles
	var offset = Vector2(0.5, 0.5)
	var c1 = Vector2(coord1) + offset
	var c2 = Vector2(coord2) + offset
	for i in range(nb_steps):
		# weighted average between the two centers
		var coord = Vector2i(((mult-i)*c1 + i*c2) / mult)
		if is_walkable(coord):
			steps.append(coord)
		else:
			return null
	return steps

func get_actors():
	## Return an array of actors presently on this board.
	var actors = []
	for node in get_children():
		if node is Actor:
			actors.append(node)
	return actors

func get_items():
	## Return an array of items presently on this board, excluding items in actors' inventory.
	## For stacked items they are returned bottom of the stack first. 
	var items = []
	for node in get_children():
		if node is Item and not node.is_expired():
			items.append(node)
	return items

func reset_items_visibility():
	## Show or hide items depending on their stacking order. No animations performed.
	# FIXME: check actors too
	var index = make_index()
	for item in get_items():
		var coord = item.get_cell_coord()
		if item == index.top_item_at(coord):
			var actor = index.actor_at(coord)
			if not actor or actor.is_dead():
				item.flash_in()
			else:
				item.hide()
		else:
			item.hide()

func _on_actor_moved(from, to):
	## fade in and out the visibility of items being stepped on/off.
	var index = make_index()
	var item = index.top_item_at(from)
	if item:
		item.fade_in()
	item = index.top_item_at(to)
	if item:
		item.fade_out()

func _on_actor_died(coord, actor):
	deregister_actor(actor)
	
func add_message(actor, message):
	# TODO check for visibility before propagating up
	emit_signal("new_message", message)

func ddump_connector(coord:Vector2i):
	var info = {"near_coord": coord}
	var conn = get_connection(coord)
	if conn != null:
		info.connected = true
	else:
		info.connected = false
		info.target = get_cell_rec(conn, "conn_target")
	print("Connector at %s: %s" % [coord_str(coord), info])
	
func ddump_connectors():
	for coord in get_connectors():
		ddump_connector(coord)

