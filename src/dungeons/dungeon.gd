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

@icon("res://assets/dcss/rock_stairs_down.png")
## A collection of boards with similar attributes
class_name Dungeon extends Node

# Spawn budget multipliers
const ITEM_MULTIPLIER = 1.3
const MONSTER_MULTIPLIER = 1.7
const VIBE_MULTIPLIER = 1.1

var prefab_map = {Vector3i(13, 3, 0): "Er", 
					Vector3i(13, 4, 0): "Er", 
					Vector3i(13, 5, 0): "Er", 
					Vector3i(13, 6, 0): "Er", 
					Vector3i(13, 7, 0): "Er", 
					Vector3i(13, 8, 0): "Er", 
					Vector3i(12, 5, 0): "WpEc",
					Vector3i(11, 5, 0): "Wp",
					Vector3i(10, 5, 0): "NpSr"
				}

@export var default_board_size := Vector2i(23, 15)
@export var start_depth := 0
@export var base_spawn_budget := 0
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
	var deck_builders = find_children("", "DeckBuilder", false)
	if deck_builders.is_empty():
		deck_builder = load("res://src/default_deck_builder.tscn").instantiate()
	else:
		deck_builder = deck_builders[0]
		
	starting_board = find_child("StartingBoard")
	if starting_board != null:
		finalize_static_board(starting_board)

func dungeon_for_loc(world_loc:Vector3i):
	## Return the name of the dungeon where `world_loc` belongs or null is it's part of the current dungeon
	assert(false, "Not implemented")

func make_builder(board, rect):
	## Return a new builder configure for the style of the current dungeon.
	var builder = BoardBuilder.new(board, rect)
	builder.floor_terrain = "floor-rough"
	builder.wall_terrain = "wall-old"	
	return builder
	
func get_boards():
	## Return all the boards that are part of this dungeon
	return find_children("", "RevBoard", false, false)

func get_board():
	## Return the active board for this dungeon or null if no boards are active
	for board in get_boards():
		if board.is_active():
			return board
	return null

func find_dungeon(name):
	## Return the dungeon named `name`.
	## All dungeons locatable by name must be siblings under a common parent.
	var node = get_parent().find_child(name, false, false)
	assert(node is Dungeon, "%s is not a Dungeon" % name)
	return node
	
func finalize_static_board(board:RevBoard):
	## do a bit of cleanup to make a static board fit in the dungeon
	assert(false, "must be overridden by sub classes of Dungeon")

func fill_new_board(builder, depth, world_loc, size):
	## put the main geometry on a freshly created board, except for connectors
	assert(false, "must be overridden by sub classes of Dungeon")
	

func build_board(depth, world_loc:Vector3i, size:Vector2i=default_board_size, prev_loc=null, neighbors=null):
	## Make a new board with fresh terrain, monsters, and items.
	var scene = load("res://src/rev_board.tscn") as PackedScene
	var new_board = scene.instantiate() as RevBoard
	new_board.depth = depth
	new_board.world_loc = world_loc
	add_child(new_board)
	new_board.owner = self
	new_board.clear()	

	var builder = make_builder(new_board, Rect2i(Vector2i.ZERO, size))
	fill_new_board(builder, depth, world_loc, size)
			
	if neighbors == null:
		neighbors = _neighbors_for_level(depth, world_loc, prev_loc)
	add_connectors(builder, neighbors)

	populate_board(builder, depth, world_loc)
	return new_board

func _region_for_loc(near_loc, far_loc):
	## Return which region should host the connector to go from near_loc to far_loc
	if near_loc.x == far_loc.x and near_loc.y == far_loc.y:
		return null
	elif near_loc.x == far_loc.x and near_loc.y > far_loc.y:
		return Consts.REG_NORTH
	elif near_loc.x == far_loc.x and near_loc.y < far_loc.y:
		return Consts.REG_SOUTH
	elif near_loc.x > far_loc.x and near_loc.y == far_loc.y:
		return Consts.REG_WEST
	elif near_loc.x < far_loc.x and near_loc.y == far_loc.y:
		return Consts.REG_EAST
	else:
		assert(false, "Can't relate where %s is relative to %s" % [near_loc, far_loc])

func add_connectors(builder:BoardBuilder, neighbors):
	## place stairs and other cross-board connectors on a board
	# TODO: 
	#   - if we have rooms, stairs should be in one of them
	#   - gateways should be next to a wall
	# both should be solvable with the predicate function

	var board = builder.board as RevBoard
	for rec in neighbors:
		var coord
		var terrain = _neighbor_connector_terrain(board.world_loc, rec.world_loc)
		var region = _region_for_loc(board.world_loc, rec.world_loc)
		if region == null:
			coord = builder.random_floor_cell()
		else:
			coord = builder.random_coord_in_region(region, board.is_floor)
		board.paint_cell(coord, terrain)
		board.set_cell_rec(coord, "conn_target", rec)

func _is_aligned(loc1:Vector3i, loc2:Vector3i):
	## Return whether world locations `loc1` and `loc2` are the same or 
	## one perfectly above the other.
	return loc1.x == loc2.x and loc1.y == loc2.y

func _neighbor_connector_terrain(near_loc:Vector3i, far_loc:Vector3i):
	## Return the terrain that should be used to make the connector between 
	## `near_loc` and `far_loc`.
	var delta = far_loc - near_loc
	if delta.z > 0:
		return "stairs-up"
	elif delta.z < 0:
		return "stairs-down"
	else:
		return "gateway"
	
func _conn_rec_for_loc(new_loc:Vector3i, cur_loc:Vector3i, prev_loc, cur_depth:int):
	## Return a conn_target record for a new location
	var far_depth:int
	if new_loc == prev_loc:
		far_depth = cur_depth - 1
	else:
		far_depth = cur_depth + 1
	var near_terrain = _neighbor_connector_terrain(cur_loc, new_loc)
	var rec = {"world_loc":new_loc, "depth":far_depth, "near_terrain":near_terrain}
	var dungeon = dungeon_for_loc(new_loc)
	if dungeon != null:
		rec.dungeon = dungeon
	return rec
	
func _neighbors_for_level(depth:int, world_loc:Vector3i, prev=null):
	## Return an array of conn_target records that a new level should be connect to
	var locs = []
	if prev != null:
		locs.append(prev)
		
	# same record we attach to the cell: {"world_loc":..., "depth":...}
	var mk_rec = _conn_rec_for_loc.bind(world_loc, prev, depth)
	var recs = locs.map(mk_rec)
	return recs

func spawn_budget(depth, budget_multiplier):
	return max(0, (base_spawn_budget + depth)*budget_multiplier)

func populate_board(builder, depth, world_loc:Vector3i):
	var index = builder.board.make_index()
	
	# fab contributions
	var fab_mandatory_cards = []
	var fab_optional_cards = []
	for fab in builder.fabs:
		fab_mandatory_cards += fab.get_mandatory_cards()
		fab_optional_cards += fab.get_optional_cards()
	
	# Items
	var budget = spawn_budget(depth, ITEM_MULTIPLIER)
	_gen_decks_and_place(builder, index, deck_builder, "Item", depth, world_loc, budget, 
						Utils.filter_nodes_by_type(fab_mandatory_cards, "Item"), 
						Utils.filter_nodes_by_type(fab_optional_cards, "Item"))
		
	# Monsters
	budget = spawn_budget(depth, MONSTER_MULTIPLIER)
	_gen_decks_and_place(builder, index, deck_builder, "Actor", depth, world_loc, budget, 
						Utils.filter_nodes_by_type(fab_mandatory_cards, "Actor"), 
						Utils.filter_nodes_by_type(fab_optional_cards, "Actor"))
	
	# Vibe
	var extra_vibe = []
	for actor in builder.board.get_actors():
		extra_vibe += actor.get_vibe_cards()
	budget = spawn_budget(depth, VIBE_MULTIPLIER)
	_gen_decks_and_place(builder, index, deck_builder, "Vibe", depth, world_loc, budget, 
						Utils.filter_nodes_by_type(fab_mandatory_cards, "Vibe"), 
						Utils.filter_nodes_by_type(fab_optional_cards, "Vibe") + extra_vibe)
	

func _gen_decks_and_draw(board_builder:BoardBuilder, index, deck_builder, card_type, 
							depth, world_loc, budget, 
							extra_mandatory_cards=[], extra_optional_cards=[]):
	## Generate the two decks for the card_type, draw from them as long as budget allows.
	## Return the drawn cards.  The caller is responsible for placing the cards on the board.
	var cards = []
	
	# mandatory cards
	var deck = deck_builder.gen_mandatory_deck(card_type, depth, world_loc, extra_mandatory_cards)
	while not deck.is_empty():
		cards.append(deck.draw())
		budget -= cards[-1].spawn_cost

	# optional cards, if we have any spawning budget left
	deck = deck_builder.gen_prob_deck(card_type, depth, world_loc, budget, extra_optional_cards)
	while not deck.is_empty() and budget > 0:
		cards.append(deck.draw())
		budget -= cards[-1].spawn_cost
	return cards

func _gen_decks_and_place(board_builder:BoardBuilder, index, deck_builder, card_type, 
							depth, world_loc, budget, 
							extra_mandatory_cards=[], extra_optional_cards=[]):
	## Generate the two decks for the card_type, draw from them as long as budget allows, 
	## and place everything on the board.
	var cards = _gen_decks_and_draw(board_builder, index, deck_builder, card_type, 
									depth, world_loc, budget, 
									extra_mandatory_cards, extra_optional_cards)
	# place distant cards in a sperarate pass once we've found them all
	var distant_cards = []
	for card in cards:
		if Utils.has_tags(card, ["spawn-distant"]):
			distant_cards.append(card)
		else:
			_place_card(card, board_builder, null, index)
	if not distant_cards.is_empty():
		var free_pred = board_builder.board.is_walkable
		var coords = board_builder.random_distant_coords(len(distant_cards), null, free_pred)
		distant_cards.shuffle()

		for i in len(distant_cards):
			_place_card(distant_cards[i], board_builder, coords[i], index, ["spawn-distant"])

func _place_card(card, builder:BoardBuilder, where=null, index=null, rm_tags=[]):
	## Instantiate a card and place in in a free spot on the board.
	## `where`: if supplied, try to place the card there, fallback nearby if needed.
	# FIXME: handle placement constraints
	var instance = card.duplicate()
	for tag in rm_tags:
		Utils.remove_tag(instance, tag)
	if where == null:
		var spawn_rect = instance.get("spawn_rect")
		if spawn_rect != null and spawn_rect.has_area():
			where = Rand.coord_in_rect(spawn_rect)
	builder.place(instance, false, where, true, null, index)
	instance.show()

func _get_conn_target_recs(board:RevBoard):
	## Return an array of connection targets from a board (actual or implied)
	var recs = []

	for coord in board.get_connectors():
		var rec = board.get_cell_rec(coord, "conn_target")
		if rec != null:
			recs.append(rec)
		else:
			rec = board.get_cell_rec(coord, "connection")
			var terrain = board.get_cell_terrain(coord)
			recs.append({"world_loc":rec.far_board.world_loc, 
						"depth":rec.far_board.depth, 
						"near_terrain":terrain})
	return recs

func regen(board:RevBoard):
	## Replace board with a freshly generated one
	var size = default_board_size
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
	return new_board
	
func new_board_for_target(old_board, conn_target):
	## Return a freshly created board that has not been connected yet.
	# This method is mostly about finding which dungeon should generate the new board.
	# See Dungeon.build_board() and it's sub-classes for the progen proper.
	var dungeon = null
	var dungeon_name = conn_target.get("dungeon")
	if dungeon_name != null:
		dungeon = find_dungeon(dungeon_name)
	else:
		dungeon = self
	assert(dungeon != null, "Dungeon can't be found for conn_target: %s" % conn_target)
	var new_loc = conn_target.world_loc
	var new_board = dungeon.build_board(conn_target.depth, new_loc, dungeon.default_board_size, old_board.world_loc)
	return new_board
 
func add_loc_prefabs(builder, world_loc:Vector3i):
	## Add the fab content to a board, return the unfabbed rect  or null if no fabs were applied
	if not prefab_map.has(world_loc):
		return
	
	var fabs = PrefabPack.parse_fabstr(prefab_map[world_loc], builder)
	if fabs == null:
		return null
	for fab in fabs:
		fab.fill()
	builder.fabs += fabs		
	var rect = PrefabPack.fabs_untouched_rect(fabs)
	return rect

