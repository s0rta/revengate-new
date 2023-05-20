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
#@onready var boards_cont: Node = find_child("Board").get_parent()
@onready var dungeons_cont: Node = %Viewport  # all dungeons must be direct descendent of this node
@onready var commands = $CommandPack
var board: RevBoard  # the active board

func _ready():
	Tender.hero = hero
	Tender.hud = hud
	Tender.viewport = %Viewport
	
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
	board = new_board
	
func get_board():
	## Return the current active board
	return board

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
		# FIXME: the dungeon should do most of that
		var conn_target = old_board.get_cell_rec(coord, "conn_target")
		var old_dungeon = old_board.get_dungeon()
		new_board = old_dungeon.new_board_for_target(old_board, conn_target)

		# connect the outgoing connector with the incomming one
		var far_coord = new_board.get_connector_for_loc(old_board.world_loc)
		conn = old_board.add_connection(coord, new_board, far_coord)
		
	new_board.new_message.connect($HUD.add_message)
	_activate_board(new_board)
	
	var builder = BoardBuilder.new(new_board)
	var index = new_board.make_index()
	var new_pos = builder.place(hero, builder.has_rooms(), conn.far_coord, true, null, index)
	$HUD.refresh_buttons_vis(null, new_pos)
	emit_signal("board_changed", new_board)
	
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

func test2():
	print("Testing: 2, 1... 2, 1!")
