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

## a dungeon with long skinny levels that are lined with small chambers
class_name Crypt extends Dungeon
const MIN_ELEV = -15
var _corridor:Array[Vector2i]  # the long corridor that devides the level in two

func dungeon_for_loc(world_loc:Vector3i):
	## Return the name of the dungeon where `world_loc` belongs or null is it's part of the current dungeon
	return null

func make_builder(board):
	## Return a new builder configure for the style of the current dungeon.
	var builder = BoardBuilder.new(board)
	builder.floor_terrain = "floor-rough"
	builder.wall_terrain = "wall"
	builder.clear_terrain = "rock"
	return builder

func _neighbors_for_level(depth:int, world_loc:Vector3i, prev=null):
	var locs = []
	if world_loc.z > MIN_ELEV:
		locs.append(world_loc + Consts.LOC_LOWER)
	if prev != null:
		locs.append(prev)

	var mk_rec = _conn_rec_for_loc.bind(world_loc, prev, depth)
	return locs.map(mk_rec)

func fill_new_board(builder:BoardBuilder, depth, world_loc, size):
	# The crypt is a long corridor with lots of small side rooms
	var orig_rect = builder.rect
	var outer_rect = builder.rect

	builder.board.paint_rect(outer_rect, builder.clear_terrain)
	var unfabbed_rect = add_loc_prefabs(builder, world_loc)
	if unfabbed_rect != null:
		outer_rect = unfabbed_rect
	builder.rect = outer_rect

	var partitions = Rand.split_rect(builder.rect, Rand.Orientation.VERTICAL, 1, builder.MIN_ROOM_SIDE)
	partitions.sort()
	var gap_start = Vector2i(partitions[0].position.x, partitions[0].end.y)
	var gap_end = gap_start + Vector2i(partitions[0].size.x - 1, 0)
	_corridor = [gap_start, gap_end]
	
	builder.board.paint_path(_corridor, builder.floor_terrain)
	builder.board.paint_path(Geom.move_path(_corridor, Vector2i.UP), builder.wall_terrain)
	builder.board.paint_path(Geom.move_path(_corridor, Vector2i.DOWN), builder.wall_terrain)
	
	var _wide_enough = func(rect): 
		return rect.size.x >= builder.MIN_ROOM_SIDE * 2
	
	for part in partitions:
		var nb_part = randi_range(2, 5)
		var sub_parts = [part]
		for i in nb_part:
			var index = Rand.rect(sub_parts, _wide_enough)
			if index == null:
				break  # this side of the corridor is full
			
			var divide = Rand.split_rect(sub_parts[index], Rand.Orientation.HORIZONTAL, 0, builder.MIN_ROOM_SIDE)
			if divide != null:
				sub_parts[index] = divide[1]
				sub_parts.insert(index, divide[0])
			else:
				break

		for sub_part in sub_parts:
			var sub_rect = Rand.sub_rect(sub_part, Vector2i.ONE*builder.MIN_ROOM_SIDE)
			builder.add_room(Room.new(sub_rect))
			_connect_room(builder, builder.rooms[-1])
	
	builder.rect = orig_rect

func _connect_room(builder:BoardBuilder, room:Room):
	## Connect a room to the central corridor
	var corridor_y = _corridor[0].y
	var side = [Consts.REG_NORTH, Consts.REG_SOUTH][int(corridor_y > room.position.y)]
	var start = room.new_door_coord(side)
	var diff = corridor_y - start.y
	var step = Vector2i(0, sign(diff))
	var coords:Array[Vector2i] = Geom.interpolate_path([start, Vector2i(start.x, corridor_y)])
	var sides = []
	for coord in coords:
		if not builder.board.is_floor(coord):
			sides = [coord + Vector2i.LEFT, coord + Vector2i.RIGHT]
			builder.board.paint_cells(sides, builder.wall_terrain)
	builder.board.paint_path(coords, builder.floor_terrain)
	
func add_connectors(builder:BoardBuilder, neighbors):
	var board = builder.board as RevBoard
	
	# first two connectors are at opposite ends of the hallway
	# subsequent ones are as far appart as possible
	var corridor_ends = _corridor.duplicate()
	corridor_ends.shuffle()
				
	var extra_coords = []
	var nb_extra = len(neighbors) - len(corridor_ends)
	if nb_extra > 0:
		extra_coords = builder.random_distant_coords(nb_extra, null, 
													board.is_floor, false, 
													corridor_ends)

	var coord: Vector2i
	for rec in neighbors:
		# Completely disregarding _region_for_loc() since the crypt does not emerge anywhere. 
		# Maintaining geographical consistency is therefore unnecessary. 
		var terrain = _neighbor_connector_terrain(board.world_loc, rec.world_loc)
		if terrain in RevBoard.STAIRS_TERRAINS and not corridor_ends.is_empty():
			coord = corridor_ends.pop_back()
		else:
			coord = extra_coords.pop_back()

		board.paint_cell(coord, terrain)
		board.set_cell_rec(coord, "conn_target", rec)
