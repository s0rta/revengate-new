# Copyright © 2022-2024 Yannick Gingras <ygingras@ygingras.net> and contributors

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
const INV_TILE_SIZE = 1.0 / TILE_SIZE  # we speed up conversion with mult rather than div
const LAYER_GEOM := 0  # the base dungeon terrain
const LAYER_HIGHLIGHTS_ACTION := 1  # highlights only when listening for player's input
const LAYER_HIGHLIGHTS_LONG := 2  # highlights that are on for most of the turn(s)
const SOURCE_ATLAS := 0
const SOURCE_SCENES := 1

# which terrains lead to other boards?
const CONNECTOR_TERRAINS = ["stairs-down", "stairs-up", "gateway"]
const STAIRS_TERRAINS = ["stairs-down", "stairs-up"]
# which terrains do we index for later retrieval?
const INDEXED_TERRAINS = CONNECTOR_TERRAINS
# plain floor without other features
const FLOOR_TERRAINS = ["floor", "floor-rough", "floor-dirt"]

# dynamic highlight tiles
const DYN_HIGHLIGHTS = {"mark-chatty": "#407014",
						"mark-chatty-default": "#86f61f",
						"mark-foe": "#701414", 
						"mark-foe-default": "f61f1f", 
						"mark-step": "#4799bc",
						"mark-step-alt": "#448e94"
						}

signal new_message(message, level, tags)
signal actor_died(board, coord, tags)

@export var ambient_light_col := Color(1, 1, 1, 1)

@export_group("Internals")
## approximate topological distance to the starting board, used for spawning difficulty
@export var depth := 0
@export var world_loc: Vector3i  ## relative positioning of this board in the world

## Per-cell custom data, unlike the per-tile data provided by TileMap
## (x, y) -> {'rec_name' -> {...}}
## known rec_names:
##  - "conn_target": this cell will eventually lead to another board ("depth", "dungeon", "world_loc")
##  - "connection": this cell leads to another board ("far_board_id", "far_coord", "far_loc")
##  - "locked": there is a locked door here ("key")
@export var _cell_records := {}

@export var _cells_by_terrain := {}  # terrain_name -> array of coords
@export var current_turn := 0
@export var board_id:int
@export var dungeon_name:String
@export var size:Vector2i

var terrain_names := {}  # name -> (terrain_set, terrain_id)
var alt_terrain_names := {}

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
	var _actor_by_id := {}

	# items can be stacked, so we store them in an array
	# the top of the stack is at the end (index=-1)
	var _coord_to_items := {}  # [x:y] -> Array
	var _item_to_coord := {}

	# there can also be more than one vibe per cell, the stacking order is arbitrary
	var _coord_to_vibes := {}  # [x:y] -> Array
	var _vibe_to_coord := {}

	var _los := {}  # [from, to] -> [[x1:y1], ..., [xn:yn]]
	var _metrics := {}  # [start, dest, free_dest, max_dist] -> dijkstra_metrics

	func _init(board_, actors, items=[], vibes=[]):
		board = board_
		for actor in actors:
			add_actor(actor)
		for item in items:
			add_item(item)
		for vibe in vibes:
			add_vibe(vibe)

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
		_actor_by_id[actor.actor_id] = actor

	func has_item(item):
		return _item_to_coord.has(item)

	func add_item(item):
		var coord = item.get_cell_coord()
		assert(coord, "trying to index an item that is not on the board")
		if not _coord_to_items.has(coord):
			_coord_to_items[coord] = []
		_coord_to_items[coord].append(item)
		_item_to_coord[item] = coord

	func add_vibe(vibe):
		var coord = vibe.get_cell_coord()
		assert(coord != null, "trying to index a vibe that is not on the board")
		if not _coord_to_vibes.has(coord):
			_coord_to_vibes[coord] = []
		_coord_to_vibes[coord].append(vibe)
		_vibe_to_coord[vibe] = coord

	func remove_actor(actor):
		var coord = _actor_to_coord[actor]
		_actor_to_coord.erase(actor)
		_coord_to_actor.erase(coord)
		_actor_by_id.erase(actor.actor_id)

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

	func refresh_vibe(vibe:Vibe, strict:=true):
		## Refresh the coordiates of `vibe` in the index.
		## strict: fail if `vibe` is not already in the index.
		if not _vibe_to_coord.has(vibe):
			if strict:
				assert(false, "Can't refresh vibe that is not already part of the index")
			else:
				return add_vibe(vibe)
		var old_coord = _vibe_to_coord[vibe]
		var new_coord = vibe.get_cell_coord()
		_coord_to_vibes[old_coord].erase(vibe)
		if not _coord_to_vibes.has(new_coord):
			_coord_to_vibes[new_coord] = []
		_coord_to_vibes[new_coord].append(vibe)
		_vibe_to_coord[vibe] = new_coord

	func is_occupied(coord):
		if _coord_to_actor.has(coord):
			return true
		return false

	func is_free(coord):
		## Return whether a cell is both walkable and unoccuppied.
		return board.is_walkable(coord) and not is_occupied(coord)

	func actor_by_id(actor_id:int):
		## Return the actor with id `actor_id` or `null` if no such actor in on this board.
		return _actor_by_id.get(actor_id)

	func actor_at(coord:Vector2i):
		## Return the actor occupying `coord` or null if there is no one there.
		return _coord_to_actor.get(coord)

	func top_item_at(coord:Vector2i):
		## return the item at the top of the stack at `coord` or null if there are no items there.
		if not _coord_to_items.has(coord) or not _coord_to_items[coord].size():
			return null
		return _coord_to_items[coord][-1]

	func nb_items_at(coord:Vector2i):
		if not _coord_to_items.has(coord):
			return 0
		else:
			return _coord_to_items[coord].size()

	func items_at(coord:Vector2i):
		return _coord_to_items.get(coord, [])

	func top_vibe_at(coord:Vector2i):
		## return visible vibe closest to the top of the stack at `coord`
		## or null if there are no vibes there.
		if not _coord_to_vibes.has(coord) or not _coord_to_vibes[coord].size():
			return null
		for i in _coord_to_vibes[coord].size():
			var vibe = _coord_to_vibes[coord][-1-i]
			if not vibe.char.is_empty():
				return vibe
		return _coord_to_vibes[coord][-1]

	func vibes_at(coord:Vector2i):
		return _coord_to_vibes.get(coord, [])

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
		if not from is Vector2i:
			from = CombatUtils.as_coord(from)
		if not to is Vector2i:
			to = CombatUtils.as_coord(to)
		if not _los.has([from, to]):
			_los[[from, to]] = board.line_of_sight(from, to)
		return _los[[from, to]]  # could be null

	func has_los(from, to):
		## Return whether there is a line of sight between `from` and `to`
		if not from is Vector2i:
			from = CombatUtils.as_coord(from)
		if not to is Vector2i:
			to = CombatUtils.as_coord(to)
		if _los.has([from, to]):
			return _los[[from, to]] != null
		elif _los.has([to, from]):
			return _los[[to, from]] != null
		else:
			return line_of_sight(from, to) != null

	func dist_metrics(start:Vector2i, dest:Vector2i=Consts.COORD_INVALID,
						free_dest:=false, max_dist:int=-1):
		## Like Board.dist_metrics(), but cached
		var key = [start, dest, free_dest, max_dist]
		if _metrics.has(key):
			return _metrics[key]
		var metrics = board.dist_metrics(start, dest, free_dest, max_dist)
		_metrics[key] = metrics
		return metrics

	func erase_dist_metrics(start:Vector2i, dest:Vector2i=Consts.COORD_INVALID,
						free_dest:=false, max_dist:int=-1):
		var key = [start, dest, free_dest, max_dist]
		if _metrics.has(key):
			_metrics.erase(key)

	func get_actors_in_sight(from, max_radius, include_center=false, only_alive=true):
		## Return a list of actors that are visible from `from`
		var actors = []
		var actor = null
		for coord in _coord_to_actor:
			if board.dist(from, coord) > max_radius:
				continue
			if coord == from and not include_center:
				continue
			actor = _coord_to_actor[coord]
			if only_alive and not actor.is_alive():
				continue
			if has_los(from, coord):
				actors.append(actor)
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

static func canvas_to_board(cpos:Vector2) -> Vector2i:
	## Return a coordinate in number of tiles from coord in pixels.
	return Vector2i(cpos.x * INV_TILE_SIZE,
					cpos.y * INV_TILE_SIZE)

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
	for name in DYN_HIGHLIGHTS:
		var tile = load("res://src/dynamic_highlight.tscn").instantiate()
		tile.modulate = DYN_HIGHLIGHTS[name]
		add_tile(tile, name)

	$AmbientLight.color = ambient_light_col
	if not board_id:
		board_id = ResourceUID.create_id()

	var tabulator:Tabulator = Tabulator.load()
	if not tabulator.enable_shaders:
		var source = tile_set.get_source(0)
		# TODO: would be better to detect which tile has a shader, but this will do for now
		for tile_id in [V.i(4, 0), V.i(5, 0), V.i(6, 0), V.i(7, 0), V.i(7, 7)]:
			var data = source.get_tile_data(tile_id, 0)
			data.material = null

	detect_terrain_names()
	detect_actors()
	reset_visibility(get_items() + get_actors() + get_vibes())

func add_tile(tile:Node, tile_name:String):
	var source = tile_set.get_source(SOURCE_SCENES)
	var scene = PackedScene.new()
	scene.pack(tile)
	var id = source.create_scene_tile(scene)
	alt_terrain_names[tile_name] = id

func detect_terrain_names():
	## Refresh the internal cache of "name" -> [tset, tid] mappings
	var name = ""
	for tset in range(tile_set.get_terrain_sets_count()):
		for tid in range(tile_set.get_terrains_count(tset)):
			name = tile_set.get_terrain_name(tset, tid)
			terrain_names[name] = [tset, tid]

func set_active(active:=true):
	## Make the board active: visible and collidable)
	visible = active
	set_layer_enabled(0, active)
	if active:
		detect_actors()
		reset_visibility(get_items() + get_actors() + get_vibes())

func is_active():
	return visible and is_layer_enabled(0)

func get_dungeon():
	## Return which dungeon this board is a part of or null if the board is not part of a dungeon.
	var parent = get_parent()
	if parent is Dungeon:
		return parent
	else:
		return null

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
	if not actor.picked_item.is_connected(_on_items_changed_at):
		actor.picked_item.connect(_on_items_changed_at)
	if not actor.dropped_item.is_connected(_on_items_changed_at):
		actor.dropped_item.connect(_on_items_changed_at)

func deregister_actor(actor):
	## disconnect our connections with `actor`
	if actor.moved.is_connected(_on_actor_moved):
		actor.moved.disconnect(_on_actor_moved)
	if actor.picked_item.is_connected(_on_items_changed_at):
		actor.picked_item.disconnect(_on_items_changed_at)
	if actor.dropped_item.is_connected(_on_items_changed_at):
		actor.dropped_item.disconnect(_on_items_changed_at)

func start_turn(new_turn:int):
	## Mark the start a new game turn
	# FIXME: handle sub_nodes dissipating while we do a multi-turn update
	for node in get_children():
		# skip dead actors
		if node.get("is_alive") and not node.is_alive():
			continue
		if node.get("start_turn"):
			node.start_turn(new_turn)
		elif node.get("start_new_turn"):
			for i in new_turn - current_turn:
				if node.is_expired():
					break
				node.start_new_turn()
	current_turn = new_turn
	reset_visibility(get_items() + get_actors() + get_vibes())

func make_index():
	var actors = get_actors()
	var items = get_items()
	var vibes = get_vibes()
	return BoardIndex.new(self, actors, items, vibes)

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
	if data == null:
		return null
	else:
		return tile_set.get_terrain_name(data.terrain_set, data.terrain)

func is_on_board(coord):
	## Return whether the coord is strictly contained inside the game board.
	## For non-rectangular boards, cells without tiles are considered outside the board.
	var bbox = get_used_rect()
	return bbox.has_point(coord) and get_cell_tile_data(0, coord) != null

func add_connection(near_coord, far_board, far_coord=null):
	## Connect this board with another one.
	## Connections has a near (self) and a far side (far_board). This method makes the
	## connection bi-directional.
	## Return the near-side of the connection
	if far_coord == null:
		far_coord = far_board.get_connector_for_loc(world_loc)
	var near_conn = {"far_board_id": far_board.board_id,
					"far_coord": far_coord,
					"far_loc": far_board.world_loc}
	set_cell_rec(near_coord, "connection", near_conn)
	far_board.set_cell_rec(far_coord, "connection", {"far_board_id": board_id,
													"far_coord": near_coord,
													"far_loc": world_loc})
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
			loc = get_cell_rec_val(coord, "connection", "far_loc")
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
	## Return an array of `world_loc` that this board will eventually connect to.
	var neighbors = []
	for coord in get_connectors():
		var conn = get_connection(coord)
		if conn != null:
			neighbors.append(conn.far_loc)
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

func is_terrain(coord, terrain):
	## Return whether the cell terrain name at `coord` is of `terrain`.
	return get_cell_terrain(coord) == terrain

func is_any_terrains(coord, terrains):
	## Return whether the cell terrain name at `coord` is any of `terrain`.
	return get_cell_terrain(coord) in terrains

func is_floor(coord:Vector2i):
	## Return whether a cell is a plain floor tile (no stairs or doors or anything fancy).
	return is_any_terrains(coord, FLOOR_TERRAINS)

func is_locked(coord:Vector2i):
	if get_cell_terrain(coord) == "door-closed":
		if get_cell_rec(coord, "locked") != null:
			return true
	return false

func lock(coord:Vector2i, key_tag:String):
	assert(get_cell_terrain(coord) == "door-closed", "Can only lock closed doors")
	set_cell_rec(coord, "locked", {"key":key_tag})

	var vibe = load("res://src/vibes/locked_door.tscn").instantiate()
	vibe.key_tag = key_tag
	add_child(vibe)
	vibe.place(coord)

func unlock(coord:Vector2i, key:Item):
	var rec = get_cell_rec(coord, "locked")
	assert(rec.key in key.tags, "%s is not the right key for this lock, expecting %s" % [key, rec.key])
	clear_cell_rec(coord, "locked")

	# remove the vibe
	var index = make_index()
	for vibe in index.vibes_at(coord):
		if vibe is LockedDoor:
			vibe.hide()
			vibe.reparent($/root)
			vibe.queue_free()

	# consume the key
	key.reparent($/root)
	key.queue_free()

func is_walkable(coord:Vector2i) -> bool:
	## Return whether a cell is walkable for normal actors
	# collision is only specified on physics layer 0
	if not is_on_board(coord):
		return false
	var tdata = get_cell_tile_data(0, coord)
	assert(tdata != null, "no data for coord=%s" % coord)
	var poly:int = tdata.get_collision_polygons_count(0)
	return poly == 0

func ring(center:Vector2i, radius:int, free:bool=true, in_board:bool=true, bbox=null, index=null) -> Array[Vector2i]:
	## Return an Array of coords that define a Chebyshev-ring around `center`.
	## In other words, the coords are arranged like a square on the game board
	## and they all have the same board.dist() metric to `center`.
	## see filter_coords() for the description of the other params
	var coords : Array[Vector2i] = []
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

func adjacents(coord:Vector2i, free:bool=true, in_board:bool=true,
				bbox=null, index=null) -> Array[Vector2i]:
	## Return an Array of coords immediately next to `coord`.
	## see filter_coords() for the description of the other params
	# This is a special case of ring()
	var coords : Array[Vector2i] = []
	for offset in Geom.ADJ_OFFSETS:
		coords.append(coord + offset)
	return filter_coords(coords, free, in_board, bbox, index)

func adjacents_walkable(coord:Vector2i, filter_pred=null) -> Array[Vector2i]:
	## Return an Array of coords immediately next to `coord`, in-board and walkable.
	## filter_pred: only coords that are true for this function are returned.
	var coords : Array[Vector2i] = []
	for offset in Geom.ADJ_OFFSETS:
		coords.append(coord + offset)
	coords = filter_coords(coords, false, true, get_used_rect())
	coords = coords.filter(is_walkable)
	if filter_pred != null:
		coords = coords.filter(filter_pred)
	return coords

func adjacents_cross(coord:Vector2i, filter_pred=null) -> Array[Vector2i]:
	## Return an Array of coords immediately up, down, left, and right of `coord`,
	## in-board and walkable.
	## filter_pred: only coords that are true for this function are returned.
	var coords : Array[Vector2i] = []
	for offset in Geom.CROSS_OFFSETS:
		coords.append(coord + offset)
	coords = filter_coords(coords, false, true, get_used_rect())
	if filter_pred != null:
		coords = coords.filter(filter_pred)
	return coords

func filter_coords(coords:Array[Vector2i], free, in_board, bbox, index=null) -> Array[Vector2i]:
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
		# definition. See the doc string in geom.gd for more details.
		coords = coords.filter(func (coord): return bbox.has_point(coord))
	if free:
		if index != null:
			assert(index is BoardIndex)
			coords = coords.filter(index.is_free)
		else:
			coords = coords.filter(is_walkable)
	return coords

static func dist(from, to):
	## Return the "game" distance between two tiles in number of moves.
	## Obstacles are not taken into account, use path() for that.
	var from_coord:Vector2i
	var to_coord:Vector2i
	if from is Vector2i:
		from_coord = from
	else:
		from_coord = CombatUtils.as_coord(from)
	if to is Vector2i:
		to_coord = to
	else:
		to_coord = CombatUtils.as_coord(to)
	return Geom.cheby_dist(from_coord, to_coord)

static func man_dist(from, to):
	## Return the Manhattan distance between to and from.
	var from_coord:Vector2i
	var to_coord:Vector2i
	if from is Vector2i:
		from_coord = from
	else:
		from_coord = CombatUtils.as_coord(from)
	if to is Vector2i:
		to_coord = to
	else:
		to_coord = CombatUtils.as_coord(to)
	return Geom.man_dist(from_coord, to_coord)

func paint_cell(coord, terrain_name, layer=LAYER_GEOM):
	paint_cells([coord], terrain_name, layer)

func paint_cells(coords, terrain_name, layer=LAYER_GEOM):
	if terrain_names.has(terrain_name):
		if terrain_name in INDEXED_TERRAINS:
			_append_terrain_cells(coords, terrain_name)
		var tkey = terrain_names[terrain_name]
		set_cells_terrain_connect(layer, coords, tkey[0], tkey[1])
	elif alt_terrain_names.has(terrain_name):
		for coord in coords:
			set_cell(layer, coord, SOURCE_SCENES, Vector2i.ZERO, alt_terrain_names[terrain_name])
	else:
		assert(false, "%s is not a valid terrain name" % [terrain_name])

func highlight_cells(coords, terrain_name="highlight-info", layer:=LAYER_HIGHLIGHTS_ACTION):
	paint_cells(coords, terrain_name, layer)

func paint_path(path:Array[Vector2i], terrain_name, layer=LAYER_GEOM, interpolate=true):
	assert(terrain_name not in INDEXED_TERRAINS, "indexing path terrain is not implemented")
	if interpolate:
		path = Geom.interpolate_path(path)
	var tkey = terrain_names[terrain_name]
	set_cells_terrain_path(layer, path, tkey[0], tkey[1])

func paint_rect(rect, terrain_name, layer=LAYER_GEOM):
	var cells = []
	for i in range(rect.size.x):
		for j in range(rect.size.y):
			cells.append(rect.position + V.i(i, j))
	paint_cells(cells, terrain_name, layer)

func clear_highlights(layer:=LAYER_HIGHLIGHTS_ACTION):
	## Remove all visible cell highlights
	clear_layer(layer)

func toggle_door(coord:Vector2i):
	var terrain = get_cell_terrain(coord)
	if terrain == "door-open":
		paint_cell(coord, "door-closed")
	elif terrain == "door-closed":
		paint_cell(coord, "door-open")
	else:
		assert(false, "not implemented")
	reset_visibility(get_actors() + get_vibes())

class MetricsContext extends RefCounted:
	var index: BoardIndex
	var start: Vector2i
	var dest: Vector2i
	var invalid_dest: bool
	var queue: DistQueue2i
	var done := {}
	var pred : Callable
	var pre_dist : int
	var post_dist : int
	var rect : Rect2i
	var metrics : DistMetrics2i

func _init_metric_context_static(start:Vector2i, dest:Vector2i, free_dest=false,
									valid_pred=null, index=null) -> MetricsContext:
	## Initialize a few internal variables that we need for building a BoardMetrics,
	## no matter which algo is used.
	## `free_dest`: does the destination have to be walkable?
	##   true: ex.: you want to go there;
	##   false: ex.: you want to get close and attack the actor standing there.
	## `valid_pred`: function to determine if a coord is valid for exploration,
	##   ex.: board.is_walkable() or index.is_free()
	## `index`: the BoardIndex to query, a fresh one will be created internally if `null`.
	var ctx := MetricsContext.new()
	ctx.rect = Rect2i(Vector2i.ONE, size)
	if index == null:
		index = make_index()
	if valid_pred == null:
		valid_pred = index.is_free

	# find the start: randomize if not provided
	if start == Consts.COORD_INVALID:
		start = Rand.coord_in_rect(ctx.rect)
		if not is_walkable(start):
			start = spiral(start, null, true, true, ctx.rect, index).next()

	var metrics = DistMetrics2i.new(size, start, dest)
	metrics.add_edge(Consts.COORD_INVALID, start)
	var invalid_dest = false
	if free_dest and dest != Consts.COORD_INVALID:
		invalid_dest = not valid_pred.call(dest)

	ctx.index = index
	ctx.start = start
	ctx.dest = dest
	ctx.invalid_dest = invalid_dest
	ctx.queue = DistQueue2i.new()
	ctx.pred = valid_pred
	ctx.metrics = metrics
	return ctx

func astar_metrics(start_:Vector2i=Consts.COORD_INVALID, dest_:Vector2i=Consts.COORD_INVALID,
					free_dest_:=false, max_dist:int=-1, valid_pred=null, index=null):
	## Return sparse BoardMetrics using the A* algorithm.
	## If max_dist is provided, only explore until max_dist depth is reached
	## and return partial metrics.
	var ctx:MetricsContext = _init_metric_context_static(start_, dest_, free_dest_, valid_pred, index)
	if ctx.invalid_dest:
		return ctx.metrics
	var estimate:int = Geom.cheby_dist(ctx.start, ctx.dest)
	# The dist used in the queue is dist is h(n), then estimate from here to the destination.
	# Ties are broken with the [g(n), man(p, n)] pair: real dist from start and
	# with Manhattan distance with the previous node to favor straigth lines over diagonals.
	var dist:int = estimate
	var tie_breaker:Array[int] = [0, 0]
	ctx.queue.enqueue(ctx.start, dist, tie_breaker)
	var current:Vector2i
	var entry: DistQueue2i.Entry
	while not ctx.queue.is_empty():
		entry = ctx.queue.dequeue()
		dist = entry.dist
		tie_breaker = entry.tie_breaker
		current = entry.coord
		if current == ctx.dest:
			break  # Done!
		elif Geom.cheby_dist(current, ctx.dest) == 1:
			# got next to dest, no need to look at adjacents()
			ctx.metrics.setv(ctx.dest, tie_breaker[0]+1)
			ctx.metrics.add_edge(current, ctx.dest)
			break
		if ctx.done.has(current) or tie_breaker[0] == max_dist:
			continue  # this position is finalized already

		for pos in adjacents_walkable(current, ctx.pred):
			if ctx.done.has(pos):
				continue
			ctx.pre_dist = ctx.metrics.getv(pos)
			if ctx.pre_dist == -1 or ctx.pre_dist > tie_breaker[0]+1:
				ctx.metrics.setv(pos, tie_breaker[0]+1)
				ctx.metrics.add_edge(current, pos)
			ctx.post_dist = Geom.cheby_dist(pos, ctx.dest)
			estimate = ctx.post_dist + tie_breaker[0]
			ctx.queue.enqueue(pos, estimate, [tie_breaker[0]+1, Geom.man_dist(pos, ctx.start)])
		ctx.done[current] = true
	return ctx.metrics

func astar_metrics_custom(pump:Paths.MetricsPump,
							start_:Vector2i=Consts.COORD_INVALID, dest_:Vector2i=Consts.COORD_INVALID,
							free_dest_:=false, max_dist:int=-1,
							valid_pred=null, index=null):
	## Return sparse BoardMetrics using the A* algorithm.
	## pump: the fully initialized extractor for the intermediate values
	## all other params like `astar_metrics()`
	var ctx:MetricsContext = _init_metric_context_static(start_, dest_, free_dest_, valid_pred, index)
	if ctx.invalid_dest:
		return ctx.metrics
	pump.set_metrics(ctx.metrics)
	var estimate:int = pump.dist_estim(ctx.start, ctx.dest)
	# dist is h(n), the estimate to dest; [g(n), tiebreak(p, n)] pairs are used to resolve ties.
	# g(n) is real path dist from start, tiebreak() is provided by the MetricsPump
	var dist:int = estimate
	var tie_breaker:Array[int] = [0, 0]
	ctx.queue.enqueue(ctx.start, dist, tie_breaker)
	var current:Vector2i
	var entry: DistQueue2i.Entry
	var adjs: Array[Vector2i]
	while not ctx.queue.is_empty():
		entry = ctx.queue.dequeue()
		dist = entry.dist
		tie_breaker = entry.tie_breaker
		current = entry.coord

		if current == ctx.dest:
			break  # Done!

		adjs = pump.adjacents(current)
		if pump.dist_real(current, ctx.dest) == 1 or ctx.dest in adjs:
			# We both look at both dist() and adjs because some pumps have step
			# increments bigger than 1.
			# Got next to dest, no need to look at adjacents()
			ctx.metrics.setv(ctx.dest, tie_breaker[0]+pump.dist_real(current, ctx.dest))
			ctx.metrics.add_edge(current, ctx.dest)
			break
		if ctx.done.has(current) or tie_breaker[0] == max_dist:
			continue  # this position is finalized already

		if ctx.pred != null:
			adjs = adjs.filter(ctx.pred)
		for pos in adjs:
			if ctx.done.has(pos):
				continue
			ctx.pre_dist = ctx.metrics.getv(pos)
			var step_dist = pump.dist_real(current, pos)
			if ctx.pre_dist == -1 or ctx.pre_dist > tie_breaker[0]+step_dist:
				ctx.metrics.setv(pos, tie_breaker[0]+step_dist)
				ctx.metrics.add_edge(current, pos)
			ctx.post_dist = pump.dist_estim(pos, ctx.dest)
			estimate = ctx.post_dist + tie_breaker[0] + step_dist
			var tiebreak:int = pump.dist_tiebreak(pos, ctx.start)
			ctx.queue.enqueue(pos, estimate, [tie_breaker[0]+step_dist, tiebreak])
		ctx.done[current] = true
	return ctx.metrics

func dist_metrics(start_:Vector2i=Consts.COORD_INVALID, dest_:Vector2i=Consts.COORD_INVALID,
					free_dest_:=false, max_dist:int=-1, max_steps:int=-1,
					valid_pred=null, index=null):
	## Return distance metrics or all positions accessible from start.
	## Start is randomly selected if not provided.
	## Stop exploring after reaching `dest` if provided.
	## Do not explore further than `max_dist` if provided.
	## Do not consider more than `max_steps` coords if provided.
	# using the Dijkstra algo
	var ctx:MetricsContext = _init_metric_context_static(start_, dest_, free_dest_, valid_pred, index)
	if ctx.invalid_dest:
		return ctx.metrics
	var dist := 0

	var known_good = {}  # used a a set

	ctx.queue.enqueue(ctx.start, dist)
	var current:Vector2i
	var entry: DistQueue2i.Entry
	var nb_steps := 0
	while not ctx.queue.is_empty():
		nb_steps += 1
		if max_steps > 0 and nb_steps >= max_steps:
			break
		entry = ctx.queue.dequeue()
		dist = entry.dist
		current = entry.coord
		if current == ctx.dest:
			break  # Done!
		elif ctx.dest != Consts.COORD_INVALID and Geom.cheby_dist(current, ctx.dest) == 1:
			# got next to dest, no need to look at adjacents()
			ctx.metrics.setv(ctx.dest, dist+1)
			ctx.metrics.add_edge(current, ctx.dest)
			break
		if ctx.done.has(current) or dist == max_dist:
			continue  # this position is finalized already

		# This inline version of `adjacent_walkable(current, ctx.pred)`
		# is about twice as fast. It depends on ctx.pred() to be sensible.
		var adjs:Array[Vector2i] = []
		for offset in Geom.ADJ_OFFSETS:
			var adj = current + offset
			if not ctx.rect.has_point(adj) or ctx.done.has(adj):
				continue
			elif known_good.has(adj):
				adjs.append(adj)
			elif ctx.pred.call(adj):
				known_good[adj] = true
				adjs.append(adj)

		for pos in adjs:
			if ctx.done.has(pos):
				continue
			ctx.pre_dist = ctx.metrics.getv(pos)
			if ctx.pre_dist == -1 or ctx.pre_dist > dist+1:
				ctx.metrics.setv(pos, dist+1)
				ctx.metrics.add_edge(current, pos)
			ctx.queue.enqueue(pos, dist+1)
		ctx.done[current] = true
	return ctx.metrics

func path(start:Vector2i, dest:Vector2i, free_dest:=true, max_dist:=-1, index=null):
	## Return an Array of coordinates from `start` to `dest`.
	## See BoardMetrics.path() for more details.
	## `free_dest`: does the destination have to be walkable?
	##   true: ex.: you want to go there;
	##   false: ex.: you want to get close and attack the actor standing there.
	var metrics = astar_metrics(start, dest, free_dest, max_dist, null, index)
	return metrics.path()

func path_potential(start:Vector2i, dest:Vector2i, max_dist:=-1, index=null):
	## Return an Array of coordinates from `start` to `dest`, only looking if cells are walkable
	## and ignoring whether they are occupied.
	var metrics = astar_metrics(start, dest, false, max_dist, is_walkable, index)
	return metrics.path()

func path_perceived(start:Vector2i, dest:Vector2i, pov_actor:Actor,
					free_dest:=true, max_dist:=-1, index=null):
	## Return an Array of coordinates from `start` to `dest` as seen by `pov_actor`.
	if index == null:
		index = make_index()
	var pred = pov_actor.perceives_free.bind(index)
	var metrics = astar_metrics(start, dest, free_dest, max_dist, pred, index)
	return metrics.path()

func path_perceived_strict(start:Vector2i, dest:Vector2i, pov_actor:Actor,
							free_dest:=true, max_dist:=-1, index=null):
	## Return an Array of coordinates from `start` to `dest` as seen by `pov_actor`
	## where every step is perceivable.
	if index == null:
		index = make_index()
	var pred = func (coord):
		return pov_actor.perceives(coord, index) and index.is_free(coord)
	var metrics = astar_metrics(start, dest, free_dest, max_dist, pred, index)
	return metrics.path()

func is_cell_unexposed(coord):
	## Return whether the hero can perceive the cell at coord
	if not visible:
		# this board is not active
		return true
	if Tender.hero and not Tender.hero.perceives(coord):
		return true
	return false

func line_of_sight(coord1, coord2):
	## Return an array of coords in the line of sight between coord1 and coord2
	## or null if the direct path is visibly obstructed.
	## Both end point params are included in the returned array.
	if not coord1 is Vector2i:
		coord1 = CombatUtils.as_coord(coord1)
	if not coord2 is Vector2i:
		coord2 = CombatUtils.as_coord(coord2)

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

func visible_coords(center, radius:int, include_center=false):
	## Return an array of coords that are visible from `center`.
	## The order or the array is arbitrary.
	center = CombatUtils.as_coord(center)
	var offset = Vector2i.ONE * (radius - 1)
	var sight_box = Rect2i(center-offset, Vector2i.ONE*(2*radius-1))
	sight_box = sight_box.intersection(get_used_rect())

	var vis = {}
	if include_center:
		vis[center] = true
	# cast a ray towards each perimeter cell and accumulate the visible coords along the way
	for end in Geom.rect_perim(sight_box):
		for coord in Geom.line(center, end).slice(1):
			if is_walkable(coord):
				vis[coord] = true
			else:
				break
	return vis.keys()

func get_actors(include_tags=null, exclude_tags=null):
	## Return an array of actors presently on this board.
	## include_tags: if provided, only actors that have all those tags are returned.
	## exclude_tags: if provided, only actors that have none of those tags are returned.
	var actors = []
	for node in get_children():
		if node is Actor:
			if include_tags != null and not Utils.has_tags(node, include_tags):
				continue
			if exclude_tags != null and Utils.has_any_tags(node, exclude_tags):
				continue
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

func get_vibes():
	## Return an array of vibes presently on this board.
	var vibes = []
	for node in get_children():
		if node is Vibe:
			vibes.append(node)
	return vibes

func reset_visibility(things:Array, index=null):
	## Show or hide things depending on whether they are perceived
	if index == null:
		index = make_index()
	for thing in things:
		if thing is Item:
			var here = thing.get_cell_coord()
			if index.nb_items_at(here) > 1 and thing == index.top_item_at(here):
				thing.display_char(Consts.LOOT_PILE_CHAR)
		if thing.should_hide(index):
			thing.hide()
		else:
			thing.show()

		if thing.should_shroud(index):
			thing.shroud(false)
		else:
			thing.unshroud(true)

func update_all_shrouding(things, index=null):
	## Shroud or reveal things that have changed perceptibility.
	## The change is animated. For an instantaneous change, consider reset_visibility().
	## nulls are silently ignored.
	for thing in things:
		if thing == null:
			continue
		var shroud_it = thing.should_shroud(index)

		if shroud_it:
			thing.shroud()
		else:
			thing.unshroud()

func update_all_actor_shrouding(index:BoardIndex):
	update_all_shrouding(get_actors(), index)

func update_shrouding_at(where, index:BoardIndex):
	## Shroud or reveal things that have changed perceptibility at a given coord.
	## See update_all_shrouding() for more details.
	var things = [index.actor_at(where), index.top_item_at(where)] + index.vibes_at(where)
	update_all_shrouding(things, index)

func _on_actor_moved(from, to):
	## fade in and out the visibility of items being stepped on/off.
	var index = make_index()
	assert(index.actor_at(to)!=null,
			"The signal seems to have fired before an actor set their dest to %s" % coord_str(to))

	if index.actor_at(to) == Tender.hero:
		var things = [index.top_item_at(from), index.top_item_at(to)] + get_actors() \
					+ index.vibes_at(from) + index.vibes_at(to)
		update_all_shrouding(things, index)
		for vibe in index.vibes_at(to):
			vibe.activate()
	elif Tender.hero:
		if Tender.hero.perceives(from, index) or Tender.hero.perceives(to, index):
			update_shrouding_at(from, index)
			update_shrouding_at(to, index)

func _on_items_changed_at(coord):
	var index = make_index() as BoardIndex
	var top = index.top_item_at(coord)
	if top == null:
		return  # nothing to do
	top.show()
	for item in index.items_at(coord):
		if item != top:
			item.hide()
	if index.actor_at(coord):
		top.shroud()
	else:
		top.unshroud()

func _on_actor_died(coord, tags, actor):
	deregister_actor(actor)
	emit_signal("actor_died", self, coord, tags)

func add_message(actor, text:String,
				level:Consts.MessageLevels=Consts.MessageLevels.INFO,
				tags:=[]):
	if level == null:
		level = Consts.MessageLevels.INFO
	if not actor.is_unexposed():
		emit_signal("new_message", text, level, tags)

func ddump_connector(coord:Vector2i):
	var info = {"near_coord": coord}
	var conn = get_connection(coord)
	if conn != null:
		info.connected = true
	else:
		info.connected = false
		info.target = get_cell_rec(coord, "conn_target")
	print("Connector at %s: %s" % [coord_str(coord), info])

func ddump_connectors():
	for coord in get_connectors():
		ddump_connector(coord)

func ddump_cell(coord):
	print("Cell data for %s:" % [coord_str(coord)])
	print("  terrain: %s" % [get_cell_terrain(coord)])
	print("  records: %s" % [_cell_records.get(coord)])
