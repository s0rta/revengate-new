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

class_name LyonSurface extends Dungeon

const START_LOC = Vector3i(13, 5, 0)
const STARTING_CONN_TARGETS = {
		Vector2i(5, 3): {"dungeon": "Traboule1"}, 
		Vector2i(21, 7): {"dungeon": "Traboule2"}, 
		Vector2i(0, 15): {"dungeon": "TroisGaulesSurface"}
	}
	
@export var min_houses := 3
@export var max_houses := 6

func dungeon_for_loc(world_loc:Vector3i):
	## Return the name of the dungeon where `world_loc` belongs or null is it's part of the current dungeon
	if world_loc.z < 0:
		return "Traboule2"
	return null

func make_builder(board, rect):
	## Return a new builder configure for the style of the current dungeon.
	var builder = BoardBuilder.new(board, rect)
	builder.clear_terrain = "floor"
	builder.floor_terrain = "floor"
	builder.wall_terrain = "wall"	
	return builder

func finalize_static_board(board:RevBoard):
	## do a bit of cleanup to make a static board fit in the dungeon
	# FIXME: a few of those can go with the parent class
	board.scan_terrain()
	board.world_loc = START_LOC
	board.lock(V.i(20, 8), "key-red")
	board.lock(V.i(3, 15), "key-blue")
	
	for coord in board.get_connectors():
		if not board.get_connection(coord):  # we only add data to the unconnected coords
			var rec = board.get_cell_rec(coord, "conn_target")
			if rec == null:
				rec = {}
			if STARTING_CONN_TARGETS.has(coord):
				rec.merge(STARTING_CONN_TARGETS[coord], true)
			rec.depth = board.depth + 1
			var terrain = board.get_cell_terrain(coord)
			var z_delta = 0
			if terrain == "stairs-up":
				z_delta = 1
			elif terrain == "stairs-down":
				z_delta = -1

			var region = Geom.coord_region(coord, board.get_used_rect())
			var loc_delta = Vector3i(region.x, region.y, z_delta)
			rec.world_loc = board.world_loc + loc_delta
			if not STARTING_CONN_TARGETS.has(coord):
				rec.dungeon = dungeon_for_loc(rec.world_loc)
			board.set_cell_rec(coord, "conn_target", rec)
	board.ddump_connectors()

func fill_new_board(builder:BoardBuilder, depth, world_loc, size):
	## put the main geometry on a freshly created board, except for connectors
	var orig_rect = builder.rect
	var outer_rect = builder.rect

	builder.board.paint_rect(outer_rect, builder.clear_terrain)
	builder.board.paint_path(Geom.rect_perim(outer_rect), builder.wall_terrain)
	var unfabbed_rect = add_loc_prefabs(builder, world_loc)
	if unfabbed_rect != null:
		outer_rect = unfabbed_rect
	
	# houses are rooms, they have a 1-tile gap all around to make the Lyon surface feel open
	builder.rect = Geom.inner_rect(outer_rect, 1)
	builder.gen_rooms(randi_range(min_houses, max_houses), false)
	builder.open_rooms()
	
	builder.rect = orig_rect
	
func add_connectors(builder:BoardBuilder, neighbors):
	## place stairs and other cross-board connectors on a board
	var board = builder.board as RevBoard
	var coord:Vector2i	
	for rec in neighbors:
		var region = _region_for_loc(board.world_loc, rec.world_loc)
		var terrain = _neighbor_connector_terrain(board.world_loc, rec.world_loc)
		if region == null:
			coord = builder.random_floor_cell()
		elif terrain == "gateway" and region != Consts.REG_CENTER:
			# TODO: also exclude the corners, diagonal entrances look off
			var is_wall = board.is_terrain.bind(builder.wall_terrain)
			var coords = Geom.rect_perim(builder.rect, region).filter(is_wall)
			assert(not coords.is_empty(), "There is no wall to punch the gateway through.")
			coord = Rand.choice(coords)
		else:
			coord = builder.random_coord_in_region(region, board.is_floor)
		board.paint_cells([coord], terrain)
		board.set_cell_rec(coord, "conn_target", rec)
