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

const MONSTERS = ["monsters/rat", 
						"monsters/labras", 
						"monsters/ghost", 
						"monsters/sulant_tiger",  
						"monsters/sahwakoon",  
						"monsters/desert_centipede",  
						"monsters/sewer_otter",
						"monsters/pacherr"]
const MAX_CARD_COPIES = 4
						
const SCENE_PATH_FMT = "res://src/%s.tscn"

@onready var hero:Actor = find_child("Hero")
@onready var hud = $HUD
@onready var boards_cont: Node = find_child("Board").get_parent()
var item_generators := []
var monster_generators := []

## Factory class to help us track which unique items have been generated.
class UniqueItemGenerator extends RefCounted:
	var done = false
	var scene_path
	var first_level
	var last_level
	var item = null
	func _init(scene_name, first_level_, last_level_):
		scene_path = SCENE_PATH_FMT % scene_name
		first_level = first_level_
		last_level = last_level_
		
	func generate(depth):
		if not done and Rand.linear_prob_test(depth, first_level-1, last_level):
			done = true
			return make_item()
		else:
			return null
		
	func make_item():
		var tree = load(scene_path) as PackedScene
		item = tree.instantiate()
		return item

class LinearGenerator extends RefCounted:
	var scene_path
	var first_level
	var last_level
	func _init(scene_name, first_level_, last_level_):
		scene_path = SCENE_PATH_FMT % scene_name
		first_level = first_level_
		last_level = last_level_
		
	func generate(depth):
		if Rand.linear_prob_test(depth, first_level-1, last_level):
			return make_item()
		else:
			return null
		
	func make_item():
		var tree = load(scene_path) as PackedScene
		return tree.instantiate()

func _ready():
	for params in [["items/missing_watch", 4, 9], 
					["items/potion_of_regen", 1, 3], 
					["items/magic_capsule_of_regen", 4, 9], 
					["items/amulet_of_strength", 2, 6],
					# weapons
					["weapons/hammer", 1, 5],
					["weapons/razor", 1, 4],
					["weapons/sword", 3, 8],
					["weapons/rapier", 5, 10],
					["weapons/saber", 5, 10],
					]:
		item_generators.append(UniqueItemGenerator.new(params[0], params[1], params[2]))
	
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

func gen_deck(budget, card_names):
	var cards = []
	
	for name in card_names:
		var card = instantiate_card(name)
		if card.spawn_cost:
			var copies = clampi(round(budget / card.spawn_cost), 0, MAX_CARD_COPIES)
			for copy in range(copies):
				cards.append(card)

	cards.shuffle()	
	return cards		

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

func talk_to(actor, conversation=null):
	## Show the speech pane for `conversation` with `actor`. 
	## conversation: if not provided, try `actor.get_conversation()`
	if conversation == null:
		conversation = actor.get_conversation()
	if conversation == null:
		get_board().add_message(hero, "%s has nothing to say." % actor.caption)
	%DialoguePane.start(conversation.res, conversation.sect)

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
		
	new_board.new_message.connect(%MessagesScreen.add_message)
	old_board.set_active(false)
	new_board.set_active(true)
	
	var builder = BoardBuilder.new(new_board)
	var index = new_board.make_index()
	builder.place(hero, true, conn.far_coord, true, null, index)
	emit_signal("board_changed", new_board)

func make_board(depth):
	## Return a brand new fully initiallized unconnected RevBoard
	var scene = load("res://src/rev_board.tscn") as PackedScene
	var new_board = scene.instantiate() as RevBoard
	new_board.depth = depth
	boards_cont.add_child(new_board)
	var builder = BoardBuilder.new(new_board)
	builder.gen_level()
	
	var index = new_board.make_index()
	
	# regular items
	var all_chars = "✄➴🌡🌷🔮🖋🚬🥊🌂⚙⚗☕🎖🖂".split()
	for i in range(1):
		var item = make_item(Rand.choice(all_chars))
		builder.place(item, false, null, true, null, index)
	
	# unique and quest items
	for gen in item_generators:
		var item = gen.generate(depth)
		if item:
			builder.place(item, false, null, true, null, index)
	
	# monsters
	var budget = max(0, depth * 3)
	var monster_deck = gen_deck(budget, MONSTERS)	
	for card in monster_deck:
		if budget >= card.spawn_cost:
			builder.place(card.duplicate(), false, null, true, null, index)
			budget -= card.spawn_cost
		
		if budget == 0:
			break
		
	return new_board


func instantiate_card(name):
	var tree = load(SCENE_PATH_FMT % name) as PackedScene	
	return tree.instantiate()	


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

func test():
	print("Testing: 1, 2... 1, 2!")
	var board = get_board()
	var c2 = V.i(1, 4)
	var c1 = V.i(8, 4)
	print("LoS from %s to %s: %s" % [c1, c2, board.line_of_sight(c1, c2)])

func test2():
	print("Testing: 2, 1... 2, 1!")
	var mem = hero.find_child("Mem")
	print("Hero knows about: %s" % [mem._facts])
	print("Last attack: %s" % [mem.recall("was_attacked")])
