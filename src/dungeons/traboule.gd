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

class_name Traboule extends Dungeon

const FIRST_MAZE = 6
const ALL_MAZES = 13

func dungeon_for_loc(world_loc:Vector3i):
	## Return the name of the dungeon where `world_loc` belongs or null is it's part of the current dungeon
	if world_loc.z >= 0:
		return "LyonSurface"
	return null

func make_builder(board, rect):
	## Return a new builder configure for the style of the current dungeon.
	var builder = BoardBuilder.new(board, rect)
	builder.floor_terrain = "floor-rough"
	builder.wall_terrain = "wall-old"	
	return builder

func fill_new_board(builder, depth, world_loc, size):
	## put the main geometry on a freshly created board, except for connectors
	var orig_rect = builder.rect
	var outer_rect = builder.rect
	
	var unfabbed_rect = add_loc_prefabs(builder, world_loc)
	if unfabbed_rect != null:
		outer_rect = unfabbed_rect

	if _lvl_is_maze(depth, world_loc):
		assert(builder.rect.size % 2 == Vector2i.ONE, "maze levels should have odd sizes")
		builder.board.paint_rect(outer_rect, builder.wall_terrain)
		var inner_rect = Rect2i(outer_rect.position+Vector2i.ONE, outer_rect.size-Vector2i.ONE*2)
		var biases = _maze_biases(depth)
		builder.gen_maze(inner_rect, biases)
	else:
		builder.board.paint_rect(outer_rect, builder.clear_terrain)
		builder.gen_rooms(randi_range(3, 6))
	builder.rect = orig_rect

func _lvl_is_maze(depth:int, world_loc:Vector3i):
	## Return whether the next board be a maze?
	if _loc_elev(world_loc) == tunneling_elevation:
		return true
	else:
		return Rand.linear_prob_test(depth, FIRST_MAZE-1, ALL_MAZES)

func _maze_biases(depth:int):
	## Return the bias params for a maze generated at a given depth
	var easy_depth = FIRST_MAZE
	var hard_depth = ALL_MAZES
	var easy_reconnect = 0.7
	var hard_reconnect = 0.3
	var diff_slope = (hard_reconnect - easy_reconnect) / (hard_depth - easy_depth)
	var diff_steps = (clamp(depth, easy_depth, hard_depth) - easy_depth)
	var reconnect = diff_steps * diff_slope + easy_reconnect
	return {"twistiness": 0.3, "branching": 0.3, "reconnect": reconnect}

func _group_neighbors_by_region(cur_world_loc:Vector3i, neighbors:Array):
	## Return a dict in the form of {region:[conn_target1, conn_target2, ...]}
	var reg_map = {}
	for rec in neighbors:
		var region = _region_for_loc(cur_world_loc, rec.world_loc)
		if not reg_map.has(region):
			reg_map[region] = []
		reg_map[region].append(rec)
	return reg_map
	
func _nb_stairs(conn_targets):
	var nb := 0
	for rec in conn_targets:
		if rec.near_terrain in RevBoard.STAIRS_TERRAINS:
			nb += 1
	return nb

func add_connectors(builder:BoardBuilder, neighbors):
	## place stairs and other cross-board connectors on a board
	var board = builder.board as RevBoard
	var index = board.make_index()
	var coord:Vector2i
	var stairs_coords:Array
	var reg_map = _group_neighbors_by_region(board.world_loc, neighbors)
	var all_conn_coords = []
	for region in Consts.ALL_REGIONS + [null]:
		var connectors = reg_map.get(region)
		if connectors == null:
			continue
		var nb_stairs = _nb_stairs(connectors)
		if nb_stairs:
			stairs_coords = builder.random_distant_coords(nb_stairs, region, board.is_floor, false, all_conn_coords, index)
		else:
			stairs_coords = []
		assert(len(stairs_coords)==nb_stairs, "The board is too full to place all the connectors")
		for rec in connectors:
			var terrain = rec.near_terrain
			if terrain == "gateway" and region != Consts.REG_CENTER and not builder.has_rooms():
				coord = Rand.coord_on_rect_perim(builder.rect, region)
			else:
				coord = stairs_coords.pop_back()
			board.paint_cell(coord, terrain)
			board.set_cell_rec(coord, "conn_target", rec)
			all_conn_coords.append(coord)
	
