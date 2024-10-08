# Copyright © 2022–2024 Yannick Gingras <ygingras@ygingras.net> and contributors

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
const CORRIDOR_DOOR_PROB = 0.7

var board: RevBoard
var rect: Rect2i
var clear_terrain = "rock"
var floor_terrain = "floor"
var wall_terrain = "wall"
var rect_room_prob := 0.1
var rooms:Array[Room] = []
var fabs = []  # prefabs that were placed on the level
var _layout_pack: JSON  # layzy loaded from res when we need it

func _init(board_:RevBoard):
	rect = Rect2i(Vector2i.ZERO, board_.size)
	board = board_

func has_rooms():
	## Return whether this builder is aware of rooms.
	return not rooms.is_empty()

func is_in_room(coord:Vector2i):
	## Return whether `coord` is inside one of the rooms known by this builder.
	for room in rooms:
		if room.has_coord(coord):
			return true
	return false

func rand_layout(max_size:Vector2i):
	## Return a room layout that is at most `max_size`.
	## Return `null` if there are no such layout
	if not _layout_pack:
		_layout_pack = load("res://assets/rooms.json")
	var size_pred = func(layout):
			return layout.size[0] <= max_size.x and layout.size[1] <= max_size.y
	var layouts = _layout_pack.data.filter(size_pred)
	if not layouts.is_empty():
		return Rand.choice(layouts)
	else:
		return null

func add_room(room: Room):
	rooms.append(room)
	board.paint_cells(room.floor_coords(), floor_terrain)
	if room.has_walls:
		var path = room.perim()
		board.paint_path(path, wall_terrain)

func room_region(room: Room):
	## Return the region that this room is mostly in.
	## It's possible that the room also spills slightly into other regions.
	var center = room.get_center()
	return Geom.coord_region(center, rect)

func random_floor_cell():
	var coord = null
	if has_rooms():
		var room = Rand.choice(rooms)
		# FIXME: would be better to ask the room for a random floor coord
		coord = Rand.coord_in_rect(room.rect)
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

func _find_maxi_min(score_rect:Rect2i, other_coords:Array, index:RevBoard.BoardIndex, valid_pred=null):
	## Return a coord that is maximal amongst the minimums of all dist_metrics.
	## In other words, find a coord that is as far as possible when all the dist_metrics
	## are considered.
	## If more than one coords have maximum min_score, then a random one is selected.
	## Return null if no suitable coord can be found.
	## score_rect: only coords inside this rect are considered. Use board.get_used_rect()
	##   to be exhaustive.
	var max_score = -INF
	var max_coords = []
	var other_metrics = []
	for other_coord in other_coords:
		other_metrics.append(index.dist_metrics(other_coord))
	for i in score_rect.size.x:
		for j in score_rect.size.y:
			var coord = score_rect.position + Vector2i(i, j)
			if valid_pred != null and not valid_pred.call(coord):
				continue
			var vals = []
			for metrics in other_metrics:
				var val = metrics.getv(coord)
				if val != null:
					vals.append(val)
			var score = vals.min()
			if score != null:
				if score == max_score:
					max_coords.append(coord)
				elif score > max_score:
					max_coords = [coord]
					max_score = score
	if not max_coords.is_empty():
		return Rand.choice(max_coords)
	else:
		return null

func random_distant_coords(nb_coords:int, region=null, valid_pred=null, strict=false, other_coords=[], index=null):
	## Return an array of random coords as distant from one another as possible.
	## region: if specified, try to pick the coords in that region
	## valid_pred: only coord that are `true` with this predicate are considered
	## strict: if false, fewer than nb_coords migth be returned and out-of-region
	##   fallbacks are considered.
	##   if true, return null rather than a partial Array when any requirement can't be satisfied.
	## other_coords: those existing coords should also be avoided
	## Only walkable coords are considered
	assert(nb_coords >= 1)
	if index == null:
		index = board.make_index()
	var coord = null
	var coords = []  # the selected coordinates
	var all_coords = other_coords + coords  # everything we have to stay away from
	var pred = func (coord):
		if coord in all_coords:
			return false
		if not board.is_walkable(coord):
			return false
		if strict and region != null and not Geom.region_has_coord(rect, region, coord):
			return false
		if valid_pred != null and not valid_pred.call(coord):
			return false
		return true

	var score_rect:Rect2i
	if region != null:
		score_rect = Geom.region_bounding_rect(rect, region)
	else:
		score_rect = rect

	# bootstrap: the system starts by finding a coord that is fairly distant from everything
	var seed = random_floor_cell()
	if other_coords.is_empty():
		all_coords.append(seed)
		coord = _find_maxi_min(score_rect, all_coords, index, pred)
		if coord != null:
			pass
		elif strict:
			return null
		else:
			# dropping the region constraint
			score_rect = rect
			coord = _find_maxi_min(score_rect, all_coords, index, pred)
			if coord == null:
				# failed to bootstrap even by allowing fallbacks
				return null

		coords.append(coord)
		# erase the bootstrap seed state
		assert(all_coords.pop_back()==seed)
		all_coords.append(coord)
		index.erase_dist_metrics(seed)

	while len(coords) < nb_coords:
		coord = _find_maxi_min(score_rect, all_coords, index, pred)
		if coord != null:
			coords.append(coord)
			all_coords.append(coord)
		elif strict:
			return null
		elif score_rect != rect:
			score_rect = rect  # forget about the region, try the whole board
		else:
			# we tried the best we could, but failed along the way
			# deliver a partial result
			break

	return coords

func gen_level(nb_rooms=4):
	## Generate a default underground level
	board.paint_rect(rect, "rock")
	gen_rooms(nb_rooms)
	add_stairs()

func gen_rooms(nb_rooms:int, add_corridors:=true):
	## Generate up to `nb_rooms` non-overlapping rooms and optionaly connect them with corridors
	## Fewer than `nb_rooms` will be generated if builder.rect is too small.
	## Return how many rooms were generated.
	var partitions = [rect]
	var nb_iter = 0
	var areas = null
	var size = null
	var indices = null
	var is_full := false
	var _large_enough = func(rect):
		return max(rect.size.x, rect.size.y) >= MIN_PART_SIZE

	if nb_rooms <= 0:
		# we need to handle this case separately in order to be able to seed partitions
		# with the whole bounding rect
		return 0
	while not is_full and partitions.size() < nb_rooms and nb_iter < 10:
		var index = Rand.rect(partitions, _large_enough)
		if index == null:
			is_full = true
			break
		var sub_parts = Rand.split_rect(partitions[index],
			Rand.Orientation.LONG_SIDE,
			ROOM_PAD,
			MIN_ROOM_SIDE)
		if sub_parts != null:
			partitions[index] = sub_parts[1]
			partitions.insert(index, sub_parts[0])
		nb_iter += 1
	for rect in partitions:
		var room:Room
		var layout
		if Rand.rftest(rect_room_prob):
			layout = rand_layout(rect.size)
		if layout == null:
			room = Room.new(Rand.sub_rect(rect, Vector2i.ONE*MIN_ROOM_SIDE))
		else:
			var sub_rect = Rand.sub_rect(rect, Vector2i(layout.size[0], layout.size[1]))
			room = Room.from_layout(layout, sub_rect.position)
		add_room(room)

	if add_corridors:
		for i in rooms.size()-1:
			if not connect_rooms_clean(rooms[i], rooms[i+1]):
				# failed to find a clean corridor, we punch through regardless of terrain
				connect_rooms(rooms[i], rooms[i+1])
	# not using rooms.size() because there might have been existing room before we started
	return partitions.size()

func open_rooms():
	## Add an opening to each of the known rooms
	for room in rooms:
		# building doors should not face the edge of the board
		var region = Geom.coord_region(room.get_center(), rect)
		var coord = room.new_door_coord(-region)
		add_door(coord, room.door_key_tag.is_empty(), room.door_key_tag)

func gen_maze(rect_, biases=null):
	## Fill rect with a maze.
	var mazer = Mazes.GrowingTree.new(self, biases, rect_, false)
	mazer.fill()

func add_door(coord, open=true, key_tag=null):
	## Change the tile at coord into a door
	## key_tag: if supplied, the door is locked with that key
	var terrain = ["door-closed", "door-open"][int(open)]
	board.paint_cell(coord, terrain)
	if key_tag:
		assert(not open, "Can only lock closed doors")
		board.lock(coord, key_tag)

func add_stairs(stairs=["stairs-up", "stairs-down"]):
	## place stairs as far appart as possible
	# TODO: stairs should always be in a room when we have rooms

	# the first two that we receice are as far as possible from one another
	var poles = find_poles()
	board.paint_cells([poles[0]], stairs.pop_front())
	if not stairs.is_empty():
		board.paint_cells([poles[1]], stairs.pop_front())
	while not stairs.is_empty():
		var coord = random_floor_cell()
		board.paint_cells([coord], stairs.pop_back())

func find_poles():
	## Return an array with the two coordinates that are the furthest apart
	## by RevBoard.dist().
	## For something more flexible, see random_distant_coords()
	# We have to do two consecutive runs of Dijkstra. The first one finds one pole,
	# the second starting at the first pole will find the second one.
	var start = null
	if has_rooms():
		start = Rand.choice(rooms).rand_coord()
	var metrics:DistMetrics2i = board.dist_metrics(start)
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
	var cells:Array[Vector2i] = []
	if v.x:
		for i in range(0, v.x, v_sign.x):
			cells.append(c1 + V.i(i, 0))
	if v.y:
		for j in range(0, v.y, v_sign.y):
			cells.append(c1 + V.i(v.x, j))
	# TODO: replaced walls should become doors
	board.paint_path(cells, floor_terrain)

func _valid_door_spot(coord) -> bool:
	# We can punch a door in a wall breach if it's not next to another opening
	# and doesn't lead to a corridor (we place the doors before carving the passage).
	var adjs = board.adjacents_cross(coord, board.is_walkable)
	return len(adjs) <= 1

func connect_rooms_clean(room1, room2) -> bool:
	## Create a passage between the two rooms.
	## This will try hard to avoid touching any other rooms or passages.
	## Return if the whether we managed to add the passage.
	var pump = Paths.CarvingPump.new(board)
	var index = board.make_index()
	var pred = func(coord): return board.is_terrain(coord, clear_terrain)
	var side_pairs = Procgen.connectable_sides(room1.rect, room2.rect)
	side_pairs.shuffle()
	# try to connect until one of the list if empty
	# early exit on success, keep looking on the outer for on failure
	for sides in side_pairs:
		var r1_perim = Procgen.connectable_near_coords(room1, sides[0], room2, sides[1])
		r1_perim = r1_perim.filter(_valid_door_spot)
		var r2_perim = Procgen.connectable_near_coords(room2, sides[1], room1, sides[0])
		r2_perim = r2_perim.filter(_valid_door_spot)
		while not (r1_perim.is_empty() or r2_perim.is_empty()):
			var start = r1_perim.pop_back()
			var end = r2_perim.pop_back()

			var metrics = board.astar_metrics_custom(pump, start, end,
													false, -1, pred, index)
			var path = metrics.path()
			if path != null:
				board.paint_cells(path, floor_terrain)
				if Rand.rstest(CORRIDOR_DOOR_PROB):
					add_door(start)
					add_door(end)
				return true
	return false

func place(thing, in_room:=true, coord=null, free:bool=true, bbox=null, index=null):
	## Put `thing` on a board cell, return where it was placed.
	## Fallback to nearby cells if needed.
	## If coord is not provided, a random position is selected.
	## No animations are performed.
	# TODO: exposing `immediate` would be a good idea
	var cell: Vector2i  # wrestling the type system into allowing null
	var spawn_tags = Utils.spawn_tags(thing)
	if coord is Vector2i:
		if in_room:
			assert(is_in_room(coord),
					("The supplied `coord` is not in a room. Pass coord=null if "
					+ "you want the builder to find a suitable in-room location."))
		cell = Vector2i(coord.x, coord.y)
	elif not spawn_tags.is_empty():
		assert(not in_room, "In-room placement is not implemented for spawn tag constraints.")
		assert(len(spawn_tags) == 1,
				"Support for multiple spawn constraint tags is not implemented")
		var tag = spawn_tags[0]
		if tag == "spawn-outside-rooms":
			cell = Rand.coord_in_rect(rect)
			var is_valid = func (coord): 
				if free and not index.is_free(coord):
					return false
				return not is_in_room(coord)
			if not is_valid.call(cell):
				var spiral = board.spiral(cell, null, free, true, rect, index)		
				while cell and not is_valid.call(cell):
					cell = spiral.next()				
		else:
			var region = Consts.REGION_NAMES[tag.split("-")[-1]]
			# not passing a pred since seeing if the cell is free comes later
			cell = random_coord_in_region(region)
		Utils.remove_tag(thing, tag)
	elif in_room:
		var room = Rand.choice(rooms)
		cell = room.rand_coord()
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
		var spiral = board.spiral(cell, null, true, true, bbox, index)
		cell = spiral.next()

	# reparent if needed
	if thing is Node:
		var parent = thing.get_parent()
		if parent and parent != board:
			thing.reparent(board)
			if thing is Actor:
				if parent is RevBoard:
					parent.deregister_actor(thing)
				board.register_actor(thing)
		elif not parent:
			board.add_child(thing)
			if thing is Actor:
				board.register_actor(thing)
		thing.owner = board

	# do the actual coord update
	thing.place(cell, true)
	if index:
		if thing is Actor:
			index.refresh_actor(thing, false)
		elif thing is Item:
			index.refresh_item(thing, false)
		elif thing is Vibe:
			index.refresh_vibe(thing, false)
		else:
			assert(false, "Indexing %s is not implemended." % thing)

	return cell
