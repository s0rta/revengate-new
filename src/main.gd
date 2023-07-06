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

@onready var hero:Actor = find_child("Hero")
@onready var hud = $HUD
@onready var dungeons_cont: Node = %Viewport  # all dungeons must be direct descendent of this node
@onready var commands = $CommandPack
var board: RevBoard  # the active board
var _seen_locs = {}  # world_locs that have been visited

func _ready():
	if Tender.story_path:
		%StoryScreen.show_story(Tender.story_title, Tender.story_path)
	Tender.reset(hero, hud, %Viewport)	
	_discover_start_board()
	hud.set_hero(hero)
	$VictoryProbe.hero = hero
	hero.died.connect(_on_hero_died)
	board_changed.connect($TurnQueue.invalidate_turn)
	board_changed.connect(center_on_hero)
	await $TurnQueue.run()
	
func _discover_start_board():
	## Find the board that the game should start with
	for dungeon in dungeons_cont.find_children("", "Dungeon", false, false):
		if dungeon.starting_board != null:
			_activate_board(dungeon.starting_board)
			break
	assert(board != null, "Could not find a starting board!")
	
func _activate_board(new_board):
	## Mark `new_board` as the current game board
	if board != null:
		board.set_active(false)
	new_board.start_turn($TurnQueue.turn)  # catch up with conditions and decay
	new_board.set_active(true)
	_seen_locs[new_board.world_loc] = true
	
	if not new_board.new_message.is_connected($HUD.add_message):
		new_board.new_message.connect($HUD.add_message)
	if not new_board.actor_died.is_connected($VictoryProbe.on_actor_died):
		new_board.actor_died.connect($VictoryProbe.on_actor_died)
	board = new_board
	print("New active board, world loc is: %s" % new_board.world_loc_str(new_board.world_loc))
	
func get_board():
	## Return the current active board
	return board

func destroy_items(items):
	for item in items:
		item.hide()
		item.reparent($/root)
		item.queue_free()
		
func supply_item(actor, item_path, extra_tags=[]):
	## Supply actor with a new instance of an item. 
	## Instantaneous: no messages nor animations.
	## Return the item.
	var item = load(item_path).instantiate()
	item.hide()
	for tag in extra_tags:
		item.tags.append(tag)
	actor.add_child(item)
	return item

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
		var conn_target = old_board.get_cell_rec(coord, "conn_target")
		var old_dungeon = old_board.get_dungeon()
		new_board = old_dungeon.new_board_for_target(old_board, conn_target)

		# connect the outgoing connector with the incomming one
		conn = old_board.add_connection(coord, new_board)
	_activate_board(new_board)
	
	var builder = BoardBuilder.new(new_board)
	var index = new_board.make_index()
	var new_pos = builder.place(hero, builder.has_rooms(), conn.far_coord, true, null, index)
	$HUD.refresh_buttons_vis(null, new_pos)
	emit_signal("board_changed", new_board)
	
func _on_hero_died(_coord, _tags):
	conclude_game(false)
	
func conclude_game(game_over:=true, victory:=false):
	## do a final bit of cleanup then show the Game Over screen
	# compile some end-of-game stats
	Tender.last_turn = $TurnQueue.turn
	Tender.nb_locs = _seen_locs.size()
	Tender.hero_stats = Tender.hero.get_base_stats()
	Tender.hero_modifiers = Tender.hero.get_modifiers()
	
	if game_over:
		$TurnQueue.shutdown()
	else:
		$TurnQueue.pause()
	if hero.is_animating():
		print("can't shutdown quite yet, hero animating...")
		# nothing else to do: Actors free() themselves after they die
		await hero.anims_done
		print("hero done animating!")
	if victory:
		%VictoryScreen.popup(game_over)
		if not game_over:
			await %VictoryScreen.start_next_chapter
			start_ch2()
	else:
		get_tree().change_scene_to_file("res://src/ui/game_over_screen.tscn")

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

func start_ch2():
	destroy_items(hero.get_items(["quest-item"]))
	# TODO: Nadège gives key and dress sword
	%Nadege.conversation_sect = "intro_2"
	supply_item(%Nadege, "res://src/items/serum_of_vitality.tscn", ["quest-reward", "gift"])
	supply_item(%Nadege, "res://src/items/key.tscn", ["key-red", "gift"])
	supply_item(%Nadege, "res://src/weapons/dress_sword.tscn", ["gift"])
	
	%BarPatron1.conversation_sect = "bloody_mary"
	%BarPatron2.conversation_sect = "party_magic"

	%BarTender.conversation_sect = "intro_2"
	supply_item(%BarTender, "res://src/items/potion_of_booze.tscn", ["gift"])

	%StoryScreen.show_story("Chapter 2: The Sound of Satin", "res://src/story/sound_of_satin.txt")
	hero.place(V.i(2, 2))
	center_on_hero()
	if $TurnQueue.is_paused():
		$TurnQueue.resume()

func test():
	print("Testing: 1, 2... 1, 2!")
	start_ch2()
	
func test2():
	print("Testing: 2, 1... 2, 1!")

	for actor in get_board().get_actors():
		print("Mana burn rate for %s is %s" % [actor, actor.get_stat("mana_burn_rate")])
		var costs = []
		for i in 12:
			costs.append(actor.mana_cost(i))
		print("  mana costs: %s" % [costs])
