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

## A collection of boards with similar attributes
class_name Dungeon extends Node

const DEF_SIZE = Vector2i(24, 16)
const FIRST_MAZE = 6
const ALL_MAZES = 13

# more than one set of stairs going up or down
const EXTRA_UP_PROB = 0.3
const EXTRA_DOWN_PROB = 0.3

@export var start_depth := 0
@export var start_world_loc: Vector3i
@export var dest_world_loc := Vector3i(3, 5, 0)
@export var tunneling_elevation := -5  # start going horizontal once we reach that depth
var deck_builder: DeckBuilder
var starting_board: RevBoard

static func opposite_connector(terrain):
	## Return the terrain that should be on the far side of a connector
	assert(terrain in RevBoard.CONNECTOR_TERRAINS)
	if terrain == "stairs-up":
		return "stairs-down"
	elif terrain == "stairs-down":
		return "stairs-up"
	else:
		return "gateway"

func _ready():
	deck_builder = find_child("DeckBuilder")
	if deck_builder == null:
		deck_builder = load("res://src/default_deck_builder.tscn").instantiate()
		
	starting_board = find_child("StartingBoard")
	if starting_board != null:
		finalize_static_board(starting_board)

func get_boards():
	## Return all the boards that are part of this dungeon
	return find_children("", "RevBoard", false, false)

func get_board():
	## Return the active board for this dungeon or null if no boards are active
	for board in get_boards():
		if board.is_active():
			return board
	return null

func make_builder(board, rect):
	## Return a new builder configure for the style of the current dungeon.
	var builder = BoardBuilder.new(board, rect)
	builder.floor_terrain = "floor-rough"
	builder.wall_terrain = "wall-old"	
	return builder

func finalize_static_board(board:RevBoard):
	## do a bit of cleanup to make a static board fit in the dungeon
	assert(false, "must be overridden by sub classes of Dungeon")

func build_board(depth, world_loc:Vector3i, size:Vector2i=DEF_SIZE, prev_loc=null, neighbors=null):
	## Make a new board with fresh terrain, monsters, and items.
	# FIXME: set the board turn
	
	var scene = load("res://src/rev_board.tscn") as PackedScene
	var new_board = scene.instantiate() as RevBoard
	new_board.depth = depth
	new_board.world_loc = world_loc
	add_child(new_board)
	new_board.clear()	
	
	var builder = make_builder(new_board, Rect2i(Vector2i.ZERO, size))
	var outer_rect = Rect2i(Vector2i.ZERO, size)
	
	if _lvl_is_maze(depth):
		# TODO: put most of this in the builder
		builder.paint_rect(outer_rect, builder.wall_terrain)
		var inner_rect = Rect2i(outer_rect.position+Vector2i.ONE, outer_rect.size-Vector2i.ONE)
		var biases = _maze_biases(depth)
		builder.gen_maze(inner_rect, biases)
	else:
		builder.paint_rect(outer_rect, "rock")
		builder.gen_rooms(randi_range(3, 6))
		
	if neighbors == null:
		neighbors = _neighbors_for_level(depth, world_loc, prev_loc)
	add_connectors(builder, neighbors)
	populate_board(builder, depth)
	return new_board

func _lvl_is_maze(depth:int):
	## Return whether the next board be a maze?
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

func add_connectors(builder, neighbors):
	## place stairs and other cross-board connectors on a board
	# TODO: if we have rooms, stairs should be in one of them

	# FIXME: if there are stairs, we should put the first two at the poles
	var board = builder.board as RevBoard
	for rec in neighbors:
		var terrain = _neighbor_connector_terrain(board.world_loc, rec.world_loc)
		var coord = builder.random_floor_cell()
		builder.paint_cells([coord], terrain)
		board.set_cell_rec(coord, "conn_target", rec)

func _is_aligned(loc1:Vector3i, loc2:Vector3i):
	## Return whether world locations `loc1` and `loc2` are the same or 
	## one perfectly above the other.
	return loc1.x == loc2.x and loc1.y == loc2.y

func _neighbor_connector_terrain(near_loc:Vector3i, far_loc:Vector3i):
	## Return the terrain that should be used to make the connector between 
	## `near_loc` and `far_loc`.
	var delta = far_loc - near_loc
	if _is_aligned(near_loc, far_loc):
		if delta.z > 0:
			return "stairs-up"
		else:
			return "stairs-down"
	else:
		return "gateway"
	
func _loc_elev(world_loc):
	var elev_to_start = (world_loc - start_world_loc).z
	var elev_to_dest = (world_loc - dest_world_loc).z
	if abs(elev_to_start) < abs(elev_to_dest):
		return elev_to_start
	else:
		return elev_to_dest
	
func _neighbors_for_level(depth:int, world_loc:Vector3i, prev=null):
	## Return an array of world locations a new level should be connect to
	
	var elev = _loc_elev(world_loc)
	
	var locs = []
	if _is_aligned(world_loc, start_world_loc) or _is_aligned(world_loc, dest_world_loc):
		locs.append(world_loc + Consts.LOC_LOWER)
		if world_loc.z < 0:
			locs.append(world_loc + Consts.LOC_HIGHER)
	if elev == tunneling_elevation:
		var dest_delta = dest_world_loc - world_loc
		var side_steps = []
		if dest_delta.x:
			side_steps.append(world_loc + sign(dest_delta.x) * Consts.LOC_EAST)
		if dest_delta.y:
			side_steps.append(world_loc + sign(dest_delta.y) * Consts.LOC_SOUTH)
		if not side_steps.is_empty():
			locs.append(Rand.choice(side_steps))
	if prev != null and prev not in locs:
		locs.append(prev)
		
	var recs = []  # same record we attach to the cell: {"world_loc":..., "depth":...}
	var far_depth = null
	for loc in locs:
		if loc == prev:
			far_depth = depth - 1
		else:
			far_depth = depth + 1
		recs.append({"world_loc":loc, "depth":far_depth})
	return recs

func populate_board(builder, depth):
	var index = builder.board.make_index()
	
	# Items
	var budget = max(0, depth*1.2)

	# mandatory items
	var deck = deck_builder.gen_mandatory_item_deck(depth)
	while not deck.is_empty():
		budget -= _place_card(deck.draw(), builder, index)
	
	# optional items, if we have any spawning budget left
	deck = deck_builder.gen_item_deck(depth, budget)
	while not deck.is_empty() and budget > 0:
		budget -= _place_card(deck.draw(), builder, index)
		
	# Monsters
	budget = max(0, depth * 2.3)
	
	# mandatory monsters
	deck = deck_builder.gen_mandatory_monster_deck(depth)
	while not deck.is_empty():
		budget -= _place_card(deck.draw(), builder, index)

	# optional monsters, if we have any spawning budget left
	deck = deck_builder.gen_monster_deck(depth, budget)
	while not deck.is_empty() and budget > 0:
		budget -= _place_card(deck.draw(), builder, index)

func _place_card(card, builder, index=null):
	## Instantiate a card and place in in a free spot on the board.
	## Return the spawn_cost of the placed card.
	var instance = card.duplicate()
	instance.show()
	builder.place(instance, builder.has_rooms(), null, true, null, index)
	return card.spawn_cost

func _get_conn_target_recs(board:RevBoard):
	## Return an array of connection targets from a board (actual or implied)
	var recs = []

	for coord in board.get_connectors():
		var rec = board.get_cell_rec(coord, "conn_target")
		if rec != null:
			recs.append(rec)
		else:
			rec = board.get_cell_rec(coord, "connection")
			recs.append({"world_loc":rec.far_board.world_loc, "depth":rec.far_board.depth})
	return recs

func regen(board:RevBoard):
	## Replace board with a freshly generater one
#	var stairs = board.get_connector_terrains()
	var size = board.get_used_rect().size
	var neighbors = _get_conn_target_recs(board)
	var new_board = build_board(board.depth, board.world_loc, size, null, neighbors)

	# Move connections from the old board to the new one
	var far_loc_to_coord = {}
	for coord in new_board.get_connectors():
		var far_loc = new_board.get_cell_rec_val(coord, "conn_target", "world_loc")
		far_loc_to_coord[far_loc] = coord

	for coord in board.get_connectors():
		var conn = board.get_connection(coord)
		if conn:
			var far_loc = conn.far_board.world_loc
			var near_coord = far_loc_to_coord[far_loc]
			new_board.add_connection(near_coord, conn.far_board, conn.far_coord)
		else:
			# nothing to do, it was not connected
			pass
			
	new_board.set_active(true)
	board.set_active(false)
	board.queue_free()
	
func new_board_for_target(old_board, conn_target):
	## Return a freshly created board that has not been connected yet.
	# This method is mostly about find which dungeon should generate the new board.
	# See Dungeon.build_board() and it's sub-classes for the progen proper.
	var dungeon = null
	var dungeon_name = conn_target.get("dungeon")
	if dungeon_name != null:
		dungeon = get_parent().find_dungeon(dungeon_name)
	else:
		dungeon = self
	assert(dungeon != null, "Dungeon can't be found for conn_target: %s" % conn_target)
	var new_loc = conn_target.world_loc
	var new_board = dungeon.build_board(conn_target.depth, new_loc, dungeon.DEF_SIZE, old_board.world_loc)
	return new_board
 
