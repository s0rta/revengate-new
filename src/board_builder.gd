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

extends RefCounted
## A factory class to generate game boards
class_name BoardBuilder

const MIN_ROOM_SIDE = 4  # 2 floor and 2 walls
const ROOM_PAD = 1  # one stone in between the walls of adjacent rooms
const MIN_PART_SIZE = MIN_ROOM_SIDE*2 + ROOM_PAD

var board: RevBoard
var rect: Rect2i
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
	
func add_room(rect: Rect2i, walls=true):
	rooms.append(rect)
	paint_rect(rect, "floor")
	if walls:
		var wall = terrain_names["wall"]
		var path = V.rect_perim(rect)	
		board.set_cells_terrain_path(0, path, wall[0], wall[1])
		
func paint_cells(cells, terrain_name):
	if terrain_name in RevBoard.INDEXED_TERRAINS:
		board._append_terrain_cells(cells, terrain_name)
	var tkey = terrain_names[terrain_name]
	board.set_cells_terrain_connect(0, cells, tkey[0], tkey[1])
	
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
	
func gen_level(nb_rooms=4):
	var bbox = board.get_used_rect()
	paint_rect(bbox, "rock")
	var partitions = [bbox]
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
	for i in rooms.size()-1:
		connect_rooms(rooms[i], rooms[i+1])
	
	# place stairs as far appart as possible
	# TODO: stairs should always be in a room
	var metrics = board.dist_metrics(Rand.pos_in_rect(Rand.choice(rooms)))
	metrics = board.dist_metrics(metrics.furthest_coord)
	var poles = [metrics.start, metrics.furthest_coord]
	poles.shuffle()
	paint_cells([poles[0]], "stairs-up")
	paint_cells([poles[1]], "stairs-down")

	
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
	paint_path(cells, "floor")

func place(thing, in_room=true, coord=null, free:bool=true, bbox=null, index=null):
	## Put `thing` on the on a board cell, return where it was placed.
	## Fallback to nearby cells if needed.
	## If coord is not provided, a random position is selected.
	## No animations are performed.
	var cell: Vector2i  # wrestling the type system into allowing null
	if coord is Vector2i:
		cell = Vector2i(coord.x, coord.y)
	elif in_room:
		cell = Rand.pos_in_rect(Rand.choice(rooms))
	else:
		if bbox == null:
			bbox = rect
		cell = Rand.pos_in_rect(bbox)

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

	thing.place(cell)
	if index:
		index.refresh_actor(thing, false)
		
	# reparent if needed
	if thing is Node:
		var parent = thing.get_parent()
		if parent and parent != board:
			parent.remove_child(thing)
		if not parent or parent != board:
			board.add_child(thing)
					
	return cell

