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
		assert(false, "Not implemented")

func _ready():
	deck_builder = find_child("DeckBuilder")
	if deck_builder == null:
		deck_builder = load("res://src/default_deck_builder.tscn").instantiate()
		
	starting_board = find_child("StartingBoard")
	if starting_board == null:
		starting_board = build_board(start_depth)

func get_boards():
	## Return all the boards that are part of this dungeon
	return find_children("", "RevBoard", false, false)

func get_board():
	## Return the active board for this dungeon or null if no boards are active
	for board in get_boards():
		if board.is_active():
			return board
	return null

func build_board(depth, size:Vector2i=DEF_SIZE, stairs=null):
	## Make a new board with fresh terrain, monsters, and items.
	# FIXME: set the board turn
	
	var scene = load("res://src/rev_board.tscn") as PackedScene
	var new_board = scene.instantiate() as RevBoard
	new_board.depth = depth
	add_child(new_board)
	new_board.clear()	
	
	var builder = BoardBuilder.new(new_board, Rect2i(Vector2i.ZERO, size))
	var outer_rect = Rect2i(Vector2i.ZERO, size)
	
	if _lvl_is_maze(depth):
		# TODO: put most of this in the builder
		builder.paint_rect(outer_rect, "wall")
		var inner_rect = Rect2i(outer_rect.position+Vector2i.ONE, outer_rect.size-Vector2i.ONE)
		var biases = _maze_biases(depth)
		builder.gen_maze(inner_rect, biases)
	else:
		builder.paint_rect(outer_rect, "rock")
		builder.gen_rooms(randi_range(3, 6))
	if stairs == null:
		stairs = _stair_for_level(depth)
	builder.add_stairs(stairs)
	
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

func _stair_for_level(depth:int):
	## Return an array of stairs tiles that should be places on a new level.
	var stairs = ["stairs-up", "stairs-down"]
	if Rand.rstest(EXTRA_UP_PROB):
		stairs.append("stairs-up")
	if Rand.rstest(EXTRA_DOWN_PROB):
		stairs.append("stairs-down")
	return stairs

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

func regen(board:RevBoard):
	## Replace board with a freshly generater one
	var stairs = board.get_connector_terrains()
	var size = board.get_used_rect().size
	var new_board = build_board(board.depth, size, stairs)
	
	for terrain in RevBoard.CONNECTOR_TERRAINS:
		var old_coords = board.get_cells_by_terrain(terrain)
		var new_coords = new_board.get_cells_by_terrain(terrain)
		assert(len(old_coords) == len(new_coords), 
				"New board was generated with a different set of connector tiles.")
		
		for i in len(old_coords):
			var conn = board.get_connection(old_coords[i])
			if conn == null:
				continue
			new_board.add_connection(new_coords[i], conn.far_board, conn.far_coord)
			
	new_board.set_active(true)
	board.set_active(false)
	# FIXME: connect the neighbour boards to the new one
	board.queue_free()
	
