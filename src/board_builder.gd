# Copyright © 2022–2023 Yannick Gingras <ygingras@ygingras.net> and contributors

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

## A factory class to generate game boards
class_name BoardBuilder extends RefCounted

const MIN_ROOM_SIDE = 4  # 2 floor and 2 walls
const ROOM_PAD = 1  # one stone in between the walls of adjacent rooms
const MIN_PART_SIZE = MIN_ROOM_SIDE*2 + ROOM_PAD

var board: RevBoard
var rect: Rect2i
var clear_terrain = "rock"
var floor_terrain = "floor"
var wall_terrain = "wall"
var terrain_names := {}
var rooms = []  # array of Rect2i, there may be walls along the perimeter

func _init(board:RevBoard, rect=null):
	self.board = board
	if rect == null:
		self.rect = board.get_used_rect()
	else:
		self.rect = rect
	update_terrain_names()
	
func update_terrain_names():
	## Refresh the internal cache of "name" -> [tset, tid] mappings
	var name = ""
	for tset in range(board.tile_set.get_terrain_sets_count()):
		for tid in range(board.tile_set.get_terrains_count(tset)):
			name = board.tile_set.get_terrain_name(tset, tid)
			terrain_names[name] = [tset, tid]

func has_rooms():
	## Return whether this builder is aware of rooms.
	return not rooms.is_empty()

func add_room(rect: Rect2i, walls=true):
	rooms.append(rect)
	paint_rect(rect, floor_terrain)
	if walls:
		var path = Geom.rect_perim(rect)	
		paint_path(path, wall_terrain)

func room_region(room: Rect2i):
	## Return the region that this room is mostly in. 
	## It's possible that the room also spills slightly into other regions.
	var center = room.get_center()
	return Geom.coord_region(center, rect)

func paint_cell(coord, terrain_name):
	paint_cells([coord], terrain_name)

func paint_cells(coords, terrain_name):
	if terrain_name in RevBoard.INDEXED_TERRAINS:
		board._append_terrain_cells(coords, terrain_name)
	var tkey = terrain_names[terrain_name]
	board.set_cells_terrain_connect(0, coords, tkey[0], tkey[1])
	
func paint_path(path, terrain_name):
	assert(terrain_name not in RevBoard.INDEXED_TERRAINS, "indexing path terrain is not implemented")
	var tkey = terrain_names[terrain_name]
	board.set_cells_terrain_path(0, path, tkey[0], tkey[1])

func paint_rect(rect, terrain_name):
	assert(terrain_name not in RevBoard.INDEXED_TERRAINS, "indexing rect terrain is not implemented")
	var cells = []
	for i in range(rect.size.x):
		for j in range(rect.size.y):
			cells.append(rect.position + V.i(i, j))
	paint_cells(cells, terrain_name)
	
func random_floor_cell():
	var coord = null
	if has_rooms():
		coord = Rand.coord_in_rect(Rand.choice(rooms))
	else:
		coord = Rand.coord_in_rect(rect)
	if board.is_walkable(coord):
		return coord
	else:
		var spiral = board.spiral(coord,  null, true, true, rect)
		for attempt in spiral:
			if board.is_floor(attempt):
				return attempt
	return null

func random_coord_in_region(region, valid_pred=null, strict=false):
	## Return a random coordinate inside the region.
	## if a callable is supplied as `valid_pred` the coord will be true for this predicate.
	## strict: coord must be in region, otherwise, a nearby fallback is acceptable when no 
	##   coords exist in region.
	## Return null if no coord can be found matching valid_pred.
	var region_rect = Geom.region_bounding_rect(rect, region)
	var coord = Rand.coord_in_rect(region_rect)
	if valid_pred == null and Geom.region_has_coord(rect, region, coord):
		return coord
	var is_valid = func (coord):
		if not Geom.region_has_coord(rect, region, coord):
			return false
		elif valid_pred != null:
			return valid_pred.call(coord)
		else:
			return true
	var spiral = board.spiral(coord, null, false)
	for c in spiral:
		if is_valid.call(c):
			return c
	if strict:
		return null
	# the region if full, falling back to nearby coords in the rest of the board
	spiral = board.spiral(coord, null, false)
	for c in spiral:
		if valid_pred:
			if valid_pred.call(c):
				return c
		else:
			return c	
	return null
	
func gen_level(nb_rooms=4):
	## Generate a default underground level
	paint_rect(rect, "rock")
	gen_rooms(nb_rooms)
	add_stairs()

func gen_rooms(nb_rooms:int, add_corridors:=true):
	## Generate `nb_rooms` non-overlapping rooms and connect them with corridors
	var partitions = [rect]
	var nb_iter = 0
	var areas = null
	var size = null
	var indices = null
	while partitions.size() < nb_rooms and nb_iter < 10:
		areas = []
		indices = []
		for i in partitions.size():
			size = partitions[i].size
			if max(size.x, size.y) < MIN_PART_SIZE:
				continue  # ignore tiny partitions
			indices.append(i)
			areas.append(partitions[i].get_area())
			
		# favor splitting the big partitions first
		var index = Rand.weighted_choice(indices, areas)
		var sub_parts = Rand.split_rect(partitions[index], 
				Rand.Orientation.LONG_SIDE, 
				ROOM_PAD, 
				MIN_ROOM_SIDE)
		if sub_parts != null:
			partitions[index] = sub_parts[1]
			partitions.insert(index, sub_parts[0])
		nb_iter += 1
	for rect in partitions:
		add_room(Rand.sub_rect(rect, MIN_ROOM_SIDE))
	if add_corridors:
		for i in rooms.size()-1:
			connect_rooms(rooms[i], rooms[i+1])

func open_rooms():
	## Add an opening to each of the known rooms
	for room in rooms:
		var region = Geom.coord_region(room.get_center(), rect)
		var coord = Rand.coord_on_rect_perim(room, -region)
		paint_cells([coord], "door-open")

func gen_maze(rect_, biases=null):
	## Fill rect with a maze.
	var mazer = Mazes.GrowingTree.new(self, biases, rect_, false)
	mazer.fill()
	
func add_stairs(stairs=["stairs-up", "stairs-down"]):
	## place stairs as far appart as possible
	# TODO: stairs should always be in a room when we have rooms
	
	# the first two that we receice are as far as possible from one another
	var poles = find_poles()
	paint_cells([poles[0]], stairs.pop_front())
	if not stairs.is_empty():
		paint_cells([poles[1]], stairs.pop_front())
	while not stairs.is_empty():
		var coord = random_floor_cell()
		paint_cells([coord], stairs.pop_back())

func find_poles():
	## Return an array with the two coordinates that are the furthest apart 
	## by RevBoard.dist().
	# We have to do two consecutive runs of Dijkstra. The first one finds one pole, 
	# the second starting at the first pole will find the second one.
	var start = null
	if has_rooms():
		start = Rand.coord_in_rect(Rand.choice(rooms))
	var metrics:RevBoard.BoardMetrics = board.dist_metrics(start)
	metrics = board.dist_metrics(metrics.furthest_coord)
	return [metrics.start, metrics.furthest_coord]

func connect_rooms(room1, room2):
	# topologicaly sort the rooms so room1 is up and left
	# TODO: this might not be needed
	var rooms = [[room1.position, room1], [room2.position, room2]]
	rooms.sort()
	room1 = rooms[0][1]
	room2 = rooms[1][1]
	
	var c1 = room1.get_center()
	var c2 = room2.get_center()
	var v = c2 - c1
	var v_sign = v.sign()
	
	# make an elbow
	var cells = []
	if v.x:
		for i in range(0, v.x, v_sign.x):
			cells.append(c1 + V.i(i, 0))
	if v.y:
		for j in range(0, v.y, v_sign.y):
			cells.append(c1 + V.i(v.x, j))
	# TODO: replaced walls should become doors
	paint_path(cells, floor_terrain)

func place(thing, in_room=true, coord=null, free:bool=true, bbox=null, index=null):
	## Put `thing` on the on a board cell, return where it was placed.
	## Fallback to nearby cells if needed.
	## If coord is not provided, a random position is selected.
	## No animations are performed.
	# TODO: exposing `immediate` would be a good idea
	var cell: Vector2i  # wrestling the type system into allowing null
	if coord is Vector2i:
		cell = Vector2i(coord.x, coord.y)
	elif in_room:
		cell = Rand.coord_in_rect(Rand.choice(rooms))
	else:
		if bbox == null:
			bbox = rect
		cell = Rand.coord_in_rect(bbox)

	var available = true
	if free:
		if index:
			available = index.is_free(cell)
		else:
			available = board.is_walkable(cell)
	if not available:
		var old_cell = cell
		# We ignore the bounding box at this point since we already failed an optimal 
		# placement and we're just trying to find a fallback.
		bbox = null  
		cell = board.spiral(cell, null, true, true, bbox, index).next()
		
	# reparent if needed
	if thing is Node:
		var parent = thing.get_parent()
		if parent and parent != board:
			parent.remove_child(thing)
			if thing is Actor and parent is RevBoard:
				parent.deregister_actor(thing)
		if not parent or parent != board:
			board.add_child(thing)
			if thing is Actor:
				board.register_actor(thing)

	# do the actual coord update	
	thing.place(cell, true)
	if index:
		if thing is Actor:
			index.refresh_actor(thing, false)
		else:
			index.refresh_item(thing, false)

	return cell

