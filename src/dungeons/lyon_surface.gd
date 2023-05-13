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

const STARTING_CONN_TARGETS = {Vector2i(5, 3): {"dungeon": "Traboule2"}}

func dungeon_for_loc(world_loc:Vector3i):
	## Return the name of the dungeon where `world_loc` belongs or null is it's part of the current dungeon
	if world_loc.z < 0:
		return "Traboule1"
	return null

func make_builder(board, rect):
	## Return a new builder configure for the style of the current dungeon.
	var builder = BoardBuilder.new(board, rect)
	builder.floor_terrain = "floor"
	builder.wall_terrain = "wall"	
	return builder

func _lvl_is_maze(depth):
	return false

func finalize_static_board(board:RevBoard):
	## do a bit of cleanup to make a static board fit in the dungeon
	board.scan_terrain()
	print("Board world loc: %s" % board.world_loc_str(board.world_loc))
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
