# Copyright © 2022-2024 Yannick Gingras <ygingras@ygingras.net> and contributors

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
var active := true  # becomes false when the run is over
var quests = []
var npcs = {}
var run_tally: Tally
var start_board_id : int
var _res_cache = []

class Quest:
	var tag: String
	var title: String
	var summary: String
	var setup_func  # Callabel, optionnal
	var intro_path: String
	var is_active: bool
	var win_events_any: Array[String]  # any of those events is a victory
	var fail_events_any: Array[String]  # any of those events is a makes you fail the quest
	var win_msg: String
	var fail_msg: String

	func _init(tag_, title_, summary_, intro_path_, win_msg_, setup_func_=null,
		win_event_any_:Array[String]=[],
		fail_event_any_:Array[String]=[], fail_msg_=""):
		assert(Utils.is_tag(tag_))
		tag = tag_
		title = title_
		summary = summary_
		intro_path = intro_path_
		win_msg = win_msg_
		setup_func = setup_func_
		win_events_any = win_event_any_
		fail_events_any = fail_event_any_
		fail_msg = fail_msg_
		is_active = false

func _ready():
	# Quests
	quests = [
		Quest.new("quest-lost-cards", "The Audition",
			"Go retrieve the lost loom cards, they will be found north west of the Café Caché",
			"res://src/story/the_audition.md",
			"You recovered the stolen loom cards."),
		Quest.new("quest-stop-accountant", "Bewitching Bookkeeping",
			"Stop Benoît the accountant from meeting with Salapou. They're supposed to meet a few blocks west of the café.",
			"res://src/story/bewitching_bookkeeping.md",
			"You prevented Benoît the accountant from exposing Frank Verguin's home lab.",
			start_ch2,
			["accountant_yeilded", "accountant_died"],
			["accountant_met_salapou"],
			"You didn't stop Benoît the accountant from selling his information."),
		Quest.new("quest-face-retznac", "The Sound of Satin",
			"Find what the book collector is up to by chasing him down the traboule. The entrance is across the main plaza.",
			"res://src/story/sound_of_satin.md",
			("You killed Retznac the vampire. "
				+ "Retznac vanished into oblivion leaving a thin trail of mist behind. "
				+ "It reminds you of the marshes around the river Rhône at sunrise."),
			start_ch3)
		]

	board_changed.connect(_on_board_changed)

	if Tender.save_bunle:
		restore_game(Tender.save_bunle)
		Tender.save_bunle = null
	else:
		SaveBundle.remove()
		run_tally = Tally.new()
		for node in dungeons_cont.find_children("", "DeckBuilder", true, false):
			node.run_tally = run_tally
		var sentiments = SentimentTable.new()
		Tender.reset(%Hero, %HUD, %Viewport, sentiments)
		Tender.quest = quests[0]
		_discover_start_board()
		watch_hero(%Hero)
		if Tender.full_game:
			%StoryScreen.show_story(quests[0].title, quests[0].intro_path)
	pre_load_resources.call_deferred()
	await $TurnQueue.run()

func _process(delta):
	Tender.play_secs += delta

func _input(_event):
	if not Utils.is_debug():
		return
	if Input.is_action_just_pressed("test-2"):
		test2()
		$/root.set_input_as_handled()
	elif Input.is_action_just_pressed("test"):
		test()
		$/root.set_input_as_handled()

func _on_board_changed(_arg):
	$TurnQueue.skip_turn(false)
	center_on_hero()

func _discover_npcs():
	npcs.nadege = board.find_child("Nadege")
	npcs.bar_patron_1 = board.find_child("BarPatron1")
	npcs.bar_patron_2 = board.find_child("BarPatron2")
	npcs.bar_tender = board.find_child("BarTender")

func _discover_start_board():
	## Find the board that the game should start with
	for dungeon in dungeons_cont.find_children("", "Dungeon", false, false):
		if dungeon.has_starting_board():
			var start_board = dungeon.finalize_static_board()
			start_board_id = start_board.board_id
			_activate_board(start_board)
			break
	assert(board != null, "Could not find a starting board!")
	
func _activate_board(new_board):
	## Mark `new_board` as the current game board
	if board != null:
		board.set_active(false)
		board.queue_free()
	new_board.start_turn($TurnQueue.turn)  # catch up with conditions and decay
	new_board.set_active(true)
	Tender.seen_locs[new_board.world_loc] = true
	
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
	hero.end_chapter.connect(conclude_game)

func get_board():
	## Return the current active board
	return board

func destroy_nodes(nodes):
	for node in nodes:
		node.hide()
		node.owner = null
		node.reparent($/root)
		node.queue_free()
		
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
		new_board = restore_board(conn.far_board_id, false)
	else:
		var old_dungeon = old_board.get_dungeon()
		var conn_target = old_board.get_cell_rec(coord, "conn_target")
		new_board = old_dungeon.new_board_for_target(old_board, conn_target)

		# connect the outgoing connector with the incomming one
		conn = old_board.add_connection(coord, new_board)		
	capture_game()
	
	var builder = BoardBuilder.new(new_board)
	var index = new_board.make_index()
	var new_pos = builder.place(Tender.hero, builder.has_rooms(),
								conn.far_coord, true, null, index)
	_activate_board(new_board)
	%HUD.refresh_buttons_vis(null, new_pos)
	board_changed.emit(new_board)
	
func _on_hero_died(_coord, _tags):
	conclude_game(false, true)

func _compile_hero_stats():
	## Compile the hero part of the game stats.
	## For the kills, see Utils.make_game_summary()
	Tender.last_turn = $TurnQueue.turn
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
		active = false
		$TurnQueue.shutdown()
		SaveBundle.remove()
	else:
		$TurnQueue.pause()
	if Tender.hero.is_animating():
		print("can't shutdown quite yet, hero animating...")
		# nothing else to do: Actors free() themselves after they die
		await Tender.hero.anims_done
		print("hero done animating!")

	%EndOfChapterScreen.show_summary(Tender.quest, victory, game_over)
	if not game_over:
		await %EndOfChapterScreen.start_next_chapter
		var quest = _next_quest(Tender.quest.tag)
		Tender.quest = quest
		assert(quest.setup_func is Callable, "We don't have a setup function for chapter %s" % quest.tag)
		quest.setup_func.call()

func center_on_hero():
	var hero_coord = Tender.hero.get_cell_coord()
	%Viewport.center_on_coord(hero_coord)

func cancel_hero_strats():
	if Tender.hero.has_strategy(true):
		Tender.hero.cancel_strategies()

func _on_turn_started(_turn):
	pass
	#get_board().clear_highlights()

func _on_turn_finished(turn):
	print("Turn %d is done." % turn)
	if not Rand.rstest(Consts.SAVE_PROB):
		return
	if active and Tender.hero and Tender.hero.is_alive():
		capture_game()

func show_context_menu_for(coord):
	## Show a list of context-specific actions.
	## Return if any of the actions taken costed a turn.
	var cmds = commands.commands_for(coord)
	%ContextMenuPopup.show_commands(cmds, coord)

func _place_on_start_board(coord:Vector2i):
	if board.board_id != start_board_id:
		var new_board = restore_board(start_board_id, false)
		_activate_board(new_board)
	var builder = BoardBuilder.new(board)
	builder.place(Tender.hero, false, coord)
	center_on_hero()
	Tender.hero.highlight_options()
	
func start_ch2():
	_place_on_start_board(V.i(2, 2))
	_discover_npcs()
	assert(npcs.nadege)
	destroy_nodes(Tender.hero.get_items(["quest-item"]))
	# Nadège gives key and combat cane
	npcs.nadege.conversation_sect = "intro_2"

	# TODO: the spellbook is probably too good of a reward, but we want to expose 
	#   the new magic mechanics, so it will have to do until we can hide it in a 
	#   side quest.
	#supply_item(npcs.nadege, "res://src/items/serum_of_vitality.tscn", ["quest-reward", "gift"])
	supply_item(npcs.nadege, "res://src/items/spellbook_of_healing.tscn", ["quest-reward", "gift"])

	supply_item(npcs.nadege, "res://src/items/key.tscn", ["key-blue", "gift"])
	supply_item(npcs.nadege, "res://src/weapons/weighted_cane.tscn", ["gift"])
	
	npcs.bar_patron_1.conversation_sect = "automata"
	npcs.bar_patron_2.conversation_sect = "resistances"

	npcs.bar_tender.conversation_sect = "intro_2"
	supply_item(npcs.bar_tender, "res://src/items/potion_of_booze.tscn", ["gift"])

	%StoryScreen.show_story("Chapter 2: Bewitching Bookkeeping",
		"res://src/story/bewitching_bookkeeping.md")
	if $TurnQueue.is_paused():
		$TurnQueue.resume()

func start_ch3():
	_place_on_start_board(V.i(2, 2))
	_discover_npcs()
	var mem = Tender.hero.mem
	# Nadège gives key and dress sword
	destroy_nodes(npcs.nadege.get_items(["quest-reward"]))
	npcs.nadege.conversation_sect = "intro_3"
	if not mem.recall("accountant_met_salapou"):
		if mem.recall("accountant_died"):
			supply_item(npcs.nadege, "res://src/items/potion_of_regen.tscn", ["quest-reward", "gift"])
			supply_item(npcs.nadege, "res://src/items/potion_of_healing.tscn", ["quest-reward", "gift"])
			supply_item(npcs.nadege, "res://src/items/dynamite.tscn", ["quest-reward", "gift"])
		elif mem.recall("accountant_yeilded"):
			supply_item(npcs.nadege, "res://src/items/serum_of_agility.tscn", ["quest-reward", "gift"])
	supply_item(npcs.nadege, "res://src/items/key.tscn", ["key-red", "gift"])
	supply_item(npcs.nadege, "res://src/weapons/dress_sword.tscn", ["gift"])
	
	npcs.bar_patron_1.conversation_sect = "bloody_mary"
	npcs.bar_patron_2.conversation_sect = "privacy"

	npcs.bar_tender.conversation_sect = "intro_3"
	supply_item(npcs.bar_tender, "res://src/items/potion_of_healing.tscn", ["gift"])

	%StoryScreen.show_story("Chapter 3: The Sound of Satin",
		"res://src/story/sound_of_satin.md")
	if $TurnQueue.is_paused():
		$TurnQueue.resume()

func pre_load_resources():
	## pre-load and cache a few expensive resources
	if not Tabulator.load().enable_shaders:
		return
	var exp_res = ["res://src/sfx/explosion_sfx.tscn",
		"res://src/sfx/magic_sfx_01.tscn",
		"res://src/sfx/magic_sfx_02.tscn",
		"res://src/sfx/zap_sfx.tscn"]
	for res in exp_res:
		ResourceLoader.load_threaded_request(res)
		
func _collect_tallies() -> Dictionary:
	## Get the tallies for distributed cards for all the dungeons. 
	## Return a {dungeon_name:tally} mapping.
	var tallies = {"run": run_tally}
	for dungeon in dungeons_cont.find_children("", "Dungeon", false, true):
		tallies[dungeon.name] = dungeon.deck_builder.tally
	return tallies
	
func _restore_tallies(tallies:Dictionary):
	## Set the tallies for distributed cards on all the dungeons. 
	## `tallies`: a {dungeon_name:tally} mapping
	if not tallies.has("run"):
		run_tally = Tally.new()
	else:
		run_tally = tallies["run"]
		
	for dungeon in dungeons_cont.find_children("", "Dungeon", false, true):
		if tallies.has(dungeon.name):
			dungeon.deck_builder.tally = tallies[dungeon.name]
			dungeon.deck_builder.run_tally = run_tally

func capture_game():
	## Record the current state of the game and save it to a file.
	var was_running = false
	if $TurnQueue.is_running():
		was_running = true
		$TurnQueue.pause()
		if not $TurnQueue.is_paused():
			await $TurnQueue.paused
	var bundle = SaveBundle.new()
	
	print("Saving at turn %d" % $TurnQueue.turn)
	bundle.save(board, start_board_id, 
		$TurnQueue.turn, _collect_tallies(),
		Tender.kills, Tender.sentiments,
		Tender.quest.tag, Tender.quest.is_active,
		Tender.seen_locs.keys(), Tender.nb_cheats, Tender.play_secs)
	if was_running:
		await $TurnQueue.resume()

func restore_board(board_id:int, keep_hero=true) -> RevBoard:
	## Load a board from disk and add it to it's dungeon. Return the board.
	## The board it not activated.
	var new_board = SaveBundle.load_board(board_id)
	if not keep_hero:
		destroy_nodes(new_board.find_children("", "Hero", false, false))
	var nodes = dungeons_cont.find_children(new_board.dungeon_name, "Dungeon", false, false)
	assert(nodes, "Can't find a dungeon named %s" % new_board.dungeon_name)
	nodes[0].add_child(new_board)
	for actor in new_board.find_children("", "Actor", false, false):
		actor.restore()
	return new_board

func restore_game(bundle=null):
	## Load a saved game and register it with all UI components
	if bundle == null:
		bundle = SaveBundle.load(true)
		print("Got the bundle loaded!")

	for board in dungeons_cont.find_children("", "RevBoard"):
		board.set_active(false)
		board.queue_free()

	var new_board = restore_board(bundle.active_board_id)
	get_tree().call_group("no-save", "queue_free")
		
	var hero = new_board.find_child("Hero")
	_restore_tallies(bundle.tallies)
	start_board_id = bundle.start_board_id
	Tender.kills = bundle.kills
	Tender.sentiments = bundle.sentiments
	Tender.quest = _quest_by_tag(bundle.quest_tag)
	Tender.quest.is_active = bundle.quest_is_active
	Tender.seen_locs.clear()
	Tender.nb_cheats = bundle.nb_cheats
	Tender.play_secs = bundle.play_secs
	Tender.viewport = %Viewport
	Tender.hud = $HUD
	for loc in bundle.seen_locs:
		Tender.seen_locs[loc] = true
	watch_hero(hero)
	$TurnQueue.turn = bundle.turn

	# FIXME: We used to do those replacements, probably to force set the owners. That does not
	#   seem to be needed anymore, but we should test more just to be sure.
	#for actor in new_board.find_children("", "Actor", false, false):
		#actor.place(actor.get_cell_coord())
		
	_activate_board(new_board)

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

func abort_run():
	## Abandon the current run, go back to Main Screen
	## The save file, if present, is kept.
	$TurnQueue.shutdown(true)
	if not $TurnQueue.is_stopped():
		await $TurnQueue.done
	capture_game()
	get_tree().change_scene_to_file("res://src/ui/start_screen.tscn")

func test():
	print("Testing: 1, 2... 1, 2!")

func test2():
	print("Testing: 2, 1... 2, 1!")
