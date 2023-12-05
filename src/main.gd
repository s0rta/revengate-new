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

@onready var dungeons_cont: Node = %Dungeons  # all dungeons must be direct descendent of this node
@onready var commands = $CommandPack
var board: RevBoard  # the active board
var _seen_locs = {}  # world_locs that have been visited
var quests = []  # int -> Quest

class Quest:
	var tag: String
	var title: String
	var setup_func  # Callabel, optionnal
	var intro_path: String
	var win_events_any: Array[String]  # any of those events is a victory
	var fail_events_any: Array[String]  # any of those events is a makes you fail the quest
	var win_msg: String
	var fail_msg: String

	func _init(tag_, title_, intro_path_, win_msg_, setup_func_=null,
			win_event_any_:Array[String]=[],
			fail_event_any_:Array[String]=[], fail_msg_=""):
		assert(Utils.is_tag(tag_))
		tag = tag_
		title = title_
		intro_path = intro_path_
		win_msg = win_msg_
		setup_func = setup_func_
		win_events_any = win_event_any_
		fail_events_any = fail_event_any_
		fail_msg = fail_msg_

func _ready():
	# Quests
	quests = [Quest.new("quest-lost-cards", "The Audition",
		"res://src/story/the_audition.md",
		"You recovered the stolen loom cards."),
		Quest.new("quest-stop-accountant", "Bewitching Bookkeeping",
			"res://src/story/bewitching_bookkeeping.md",
			"You prevented Benoît the accountant from exposing Frank Verguin's home lab.",
			start_ch2,
			["accountant_yeilded", "accountant_died"],
			["accountant_met_salapou"],
			"You didn't stop Benoît the accountant from selling his information."),
		Quest.new("quest-face-retznac", "The Sound of Satin",
			"res://src/story/sound_of_satin.md",
			("You killed Retznac the vampire. "
				+ "Retznac vanished into oblivion leaving a thin trail of mist behind. "
				+ "It reminds you of the marshes around the river Rhône at sunrise."),
			start_ch3)]

	board_changed.connect($TurnQueue.invalidate_turn)
	board_changed.connect(center_on_hero)

	if Tender.save_bunle:
		restore_game(Tender.save_bunle)
		Tender.save_bunle = null
	else:
		var sentiments = SentimentTable.new()
		Tender.reset(%Hero, %HUD, %Viewport, sentiments)
		Tender.quest = quests[0]
		_discover_start_board()
		watch_hero(%Hero)
		if Tender.full_game:
			%StoryScreen.show_story(quests[0].title, quests[0].intro_path)
	await $TurnQueue.run()

func _input(_event):
	if Input.is_action_just_pressed("test-2"):
		test2()
		$/root.set_input_as_handled()
	elif Input.is_action_just_pressed("test"):
		test()
		$/root.set_input_as_handled()

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
	$VictoryProbe.assay_victory(new_board)
	if not new_board.actor_died.is_connected($VictoryProbe.on_actor_died):
		new_board.actor_died.connect($VictoryProbe.on_actor_died)
	board = new_board
	print("New active board, world loc is: %s" % new_board.world_loc_str(new_board.world_loc))

func watch_hero(hero:Actor):
	## Connect the relevant signals on a new hero
	Tender.hero = hero
	%HUD.watch_hero(hero)
	hero.died.connect(_on_hero_died)

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
	%InventoryScreen.fill_actor_items(Tender.hero)
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
	var new_pos = builder.place(Tender.hero, builder.has_rooms(),
		conn.far_coord, true, null, index)
	%HUD.refresh_buttons_vis(null, new_pos)
	emit_signal("board_changed", new_board)
	
func _on_hero_died(_coord, _tags):
	conclude_game(false, true)

func _compile_hero_stats():
	## Compile the hero part of the game stats.
	## For the kills, see Utils.make_game_summary()
	Tender.last_turn = $TurnQueue.turn
	Tender.nb_locs = _seen_locs.size()
	Tender.hero_stats = Tender.hero.get_base_stats()
	Tender.hero_modifiers = Tender.hero.get_modifiers()

func _quest_by_tag(quest_tag):
	assert(Utils.is_tag(quest_tag))
	var nb_quests = len(quests)
	for quest in quests:
		if quest.tag == quest_tag:
			return quest
	return null
	
func _next_quest(quest_tag):
	## Return the next quest if it exists, null otherwise (end of game or invalid tag)
	assert(Utils.is_tag(quest_tag))
	var nb_quests = len(quests)
	for i in nb_quests - 1:
		if quests[i].tag == quest_tag:
			return quests[i+1]
	return null

func conclude_game(victory:bool, game_over:bool):
	## do a final bit of cleanup then show the Game Over screen
	_compile_hero_stats()
	var last_quest = Tender.quest
	
	if game_over:
		$TurnQueue.shutdown()
	else:
		$TurnQueue.pause()
	if Tender.hero.is_animating():
		print("can't shutdown quite yet, hero animating...")
		# nothing else to do: Actors free() themselves after they die
		await Tender.hero.anims_done
		print("hero done animating!")

	%EndOfChapterScreen.popup(Tender.quest, victory, game_over)
	if not game_over:
		await %EndOfChapterScreen.start_next_chapter
		var quest = _next_quest(Tender.quest.tag)
		Tender.quest = quest
		assert(quest.setup_func is Callable, "We don't have a setup function for chapter %s" % quest.tag)
		quest.setup_func.call()

func center_on_hero(_arg=null):
	var hero_coord = Tender.hero.get_cell_coord()
	%Viewport.center_on_coord(hero_coord)

func _on_cancel_button_pressed():
	Tender.hero.cancel_strategies()

func _on_turn_started(_turn):
	get_board().clear_highlights()

func show_context_menu_for(coord) -> bool:
	## Show a list of context-specific actions.
	## Return if any of the actions taken costed a turn.
	var cmds = commands.commands_for(coord)
	%ContextMenuPopup.show_commands(cmds, coord)
	var acted = await %ContextMenuPopup.closed
	return acted

func start_ch2():
	var hero = Tender.hero
	destroy_items(hero.get_items(["quest-item"]))
	# Nadège gives key and combat cane
	%Nadege.conversation_sect = "intro_2"
	supply_item(%Nadege, "res://src/items/serum_of_vitality.tscn", ["quest-reward", "gift"])
	supply_item(%Nadege, "res://src/items/key.tscn", ["key-blue", "gift"])
	supply_item(%Nadege, "res://src/weapons/weighted_cane.tscn", ["gift"])
	
	%BarPatron1.conversation_sect = "automata"
	%BarPatron2.conversation_sect = "resistances"

	%BarTender.conversation_sect = "intro_2"
	supply_item(%BarTender, "res://src/items/potion_of_booze.tscn", ["gift"])

	%StoryScreen.show_story("Chapter 2: Bewitching Bookkeeping",
		"res://src/story/bewitching_bookkeeping.md")
	hero.place(V.i(2, 2))
	center_on_hero()
	if $TurnQueue.is_paused():
		$TurnQueue.resume()

func start_ch3():
	var mem = Tender.hero.mem
	# Nadège gives key and dress sword
	destroy_items(%Nadege.get_items(["quest-reward"]))
	%Nadege.conversation_sect = "intro_3"
	if not mem.recall("accountant_met_salapou"):
		if mem.recall("accountant_died"):
			supply_item(%Nadege, "res://src/items/potion_of_regen.tscn", ["quest-reward", "gift"])
			supply_item(%Nadege, "res://src/items/potion_of_healing.tscn", ["quest-reward", "gift"])
			supply_item(%Nadege, "res://src/items/dynamite.tscn", ["quest-reward", "gift"])
		elif mem.recall("accountant_yeilded"):
			supply_item(%Nadege, "res://src/items/serum_of_agility.tscn", ["quest-reward", "gift"])
	supply_item(%Nadege, "res://src/items/key.tscn", ["key-red", "gift"])
	supply_item(%Nadege, "res://src/weapons/dress_sword.tscn", ["gift"])
	
	%BarPatron1.conversation_sect = "bloody_mary"
	%BarPatron2.conversation_sect = "party_magic"

	%BarTender.conversation_sect = "intro_3"
	supply_item(%BarTender, "res://src/items/potion_of_healing.tscn", ["gift"])

	%StoryScreen.show_story("Chapter 3: The Sound of Satin",
		"res://src/story/sound_of_satin.md")
	Tender.hero.place(V.i(2, 2))
	center_on_hero()
	if $TurnQueue.is_paused():
		$TurnQueue.resume()

func capture_game():
	## Record the current state of the game and save it to a file.
	$TurnQueue.pause()
	if not $TurnQueue.is_paused():
		await $TurnQueue.paused
	var bundle = SaveBundle.new()
	var dungeons = dungeons_cont
	
	bundle.save(dungeons, $TurnQueue.turn, Tender.kills, Tender.sentiments, 
				Tender.quest.tag)
	await $TurnQueue.run()  # might be better to send this to the background
	
func restore_game(bundle=null):
	## Load a saved game and register it with all UI components
	if bundle == null:
		bundle = SaveBundle.load(true)
		print("Got the bundle loaded!")
	var dungeons = bundle.root

	dungeons_cont.add_sibling(dungeons)
	dungeons_cont.reparent($"/root")
	
	for board in dungeons_cont.find_children("", "RevBoard"):
		board.set_active(false)
	dungeons_cont.queue_free()
	dungeons_cont = dungeons
	
	bundle.dlog_root(".final")
	watch_hero(dungeons.find_child("Hero"))
	Tender.kills = bundle.kills
	Tender.sentiments = bundle.sentiments
	Tender.quest = _quest_by_tag(bundle.quest_tag)

	for board in dungeons_cont.find_children("", "RevBoard"):
		if board.is_active():
			_activate_board(board)
			break

func replace_with_saved_game():
	## Replace the current game with one from a saved file
	print("Shutting down the queue...")
	$TurnQueue.shutdown()
	if not Tender.hero.is_idle():
		Tender.hero.cancel_action()
	if not $TurnQueue.is_stopped():
		await $TurnQueue.done
	print("Shutting down the queue: done!")

	restore_game()

	print("Restarting the queue...")
	await $TurnQueue.run()  # might be better to send this to the background
	print("Restarting the queue: done!")
		
func test():
	print("Testing: 1, 2... 1, 2!")

	capture_game()
	print("Done saving!")


func test2():
	print("Testing: 2, 1... 2, 1!")

	restore_game()
	print("Done restoring!")

