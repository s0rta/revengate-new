# Copyright © 2022-2023 Yannick Gingras <ygingras@ygingras.net> and contributors

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

extends Node2D

# The hero moved to a different level, the UI and turn logic are affected and must be notified
signal board_changed(new_board)
						
const SCENE_PATH_FMT = "res://src/%s.tscn"

@onready var hero:Actor = find_child("Hero")
@onready var hud = $HUD
@onready var boards_cont: Node = find_child("Board").get_parent()
@onready var commands = $CommandPack

func _ready():
	Tender.hero = hero
	Tender.hud = hud
	Tender.viewport = %Viewport
	
	# FIXME: the original board should be able to re-index it's content
	var board = find_child("Board")
	assert(board, "Can't find the first game board")
	board._append_terrain_cells([V.i(23, 2)], "stairs-down")
	hud.set_hero(hero)
	$VictoryProbe.hero = hero
	hero.died.connect(_on_hero_died)
	board_changed.connect($TurnQueue.invalidate_turn)
	board_changed.connect(center_on_hero)
	await $TurnQueue.run()

func get_board():
	## Return the current active board
	var current = null
	assert(boards_cont, "Board container must be initialized")
	for node in boards_cont.get_children():
		if node is RevBoard and node.visible:
			current = node
	if current:
		return current
	else:
		return find_child("Board")

func show_inventory_screen() -> bool:
	## popup the inventory screen
	## return if something considered a turn action happened while it was open
	%InventoryScreen.fill_actor_items(hero)
	%InventoryScreen.popup()
	var acted = await %InventoryScreen.closed
	return acted

func switch_board_at(coord):
	## Flip the active board with the far side of the connector at `coord`, 
	## move the Hero to the new active board.
	## If the destination does not exist yet, create and link it with the current board.
	var old_board = get_board()
	assert(old_board.is_connector(coord), "can only switch board at a connector cell")
	var new_board = null
	var conn = old_board.get_connection(coord)
	if conn:
		new_board = conn.far_board
	else:
		new_board = make_board(old_board.depth + 1)
		# connect the stairs together
		var far = new_board.get_cell_by_terrain("stairs-up")
		# TODO: add_connection() should return the new record
		old_board.add_connection(coord, new_board, far)		
		conn = old_board.get_connection(coord)
		
	new_board.new_message.connect($HUD.add_message)
	old_board.set_active(false)
	new_board.start_turn($TurnQueue.turn)  # catch up with conditions and decay
	new_board.set_active(true)
	
	var builder = BoardBuilder.new(new_board)
	var index = new_board.make_index()
	var new_pos = builder.place(hero, true, conn.far_coord, true, null, index)
	$HUD.refresh_buttons_vis(null, new_pos)
	emit_signal("board_changed", new_board)

func _place_card(card, builder, index=null):
	## Instantiate a card and place in in a free spot on the board.
	## Return the spawn_cost of the placed card.
	var instance = card.duplicate()
	instance.show()
	builder.place(instance, false, null, true, null, index)
	return card.spawn_cost

func make_board(depth):
	## Return a brand new fully initiallized unconnected RevBoard
	var scene = load("res://src/rev_board.tscn") as PackedScene
	var new_board = scene.instantiate() as RevBoard
	new_board.depth = depth
	new_board.current_turn = $TurnQueue.turn
	boards_cont.add_child(new_board)
	var builder = BoardBuilder.new(new_board)
	builder.gen_level()
	
	var index = new_board.make_index()
	
	# Items
	var budget = max(0, depth*1.2)

	# mandatory items
	var deck = %DeckBuilder.gen_mandatory_item_deck(depth)
	while not deck.is_empty():
		budget -= _place_card(deck.draw(), builder, index)
	
	# optional items, if we have any spawning budget left
	deck = %DeckBuilder.gen_item_deck(depth, budget)
	while not deck.is_empty() and budget > 0:
		budget -= _place_card(deck.draw(), builder, index)
		
	# Monsters
	budget = max(0, depth * 3)
	
	# mandatory monsters
	deck = %DeckBuilder.gen_mandatory_monster_deck(depth)
	while not deck.is_empty():
		budget -= _place_card(deck.draw(), builder, index)

	# optional monsters, if we have any spawning budget left
	deck = %DeckBuilder.gen_monster_deck(depth, budget)
	while not deck.is_empty() and budget > 0:
		budget -= _place_card(deck.draw(), builder, index)

	return new_board

func make_item(char):
	var tree = load("res://src/items/item.tscn") as PackedScene
	var item = tree.instantiate()
	item.char = char
	return item
	
func _on_hero_died(_coord):
	conclude_game(false)
	
func conclude_game(victory:=false):
	## do a final bit of cleanup then show the Game Over screen
	$TurnQueue.shutdown()
	if hero.is_animating():
		print("can't shutdown quite yet, hero animating...")
		# nothing else to do: Actors free() themselves after they die
		await hero.anims_done
		print("hero done animating!")
	var tree = get_tree() as SceneTree
	if victory:
		tree.change_scene_to_file("res://src/ui/victory_screen.tscn")
	else:
		tree.change_scene_to_file("res://src/ui/game_over_screen.tscn")

func center_on_hero(_arg=null):
	find_child("Viewport").center_on_coord(hero.get_cell_coord())

func _input(_event):
	if Input.is_action_just_pressed("test-2"):
		test2()
		$/root.set_input_as_handled()
	elif Input.is_action_just_pressed("test"):
		test()
		$/root.set_input_as_handled()

func _on_cancel_button_pressed():
	hero.cancel_strategies()

func show_context_menu_for(coord):
	var cmds = commands.commands_for(coord)
	%ContextMenuPopup.show_commands(cmds, coord)
	var acted = await %ContextMenuPopup.closed
	return acted

func test():
	print("Testing: 1, 2... 1, 2!")
	%Viewport.effect_at_coord("explosion_vfx", hero.get_cell_coord())

func test2():
	print("Testing: 2, 1... 2, 1!")
	
	var outer_rect = Rect2i(1, 1, 27, 17)
	var inner_rect = Rect2i(2, 2, 26, 16)

	var builder = BoardBuilder.new(get_board())
	builder.paint_rect(outer_rect, "wall")
	var biases = Mazes.GrowingTree.DEF_BIASES.duplicate()
	biases["branching"] = 0.5
	var mazer = Mazes.GrowingTree.new(builder, biases, inner_rect)
	mazer.fill()
