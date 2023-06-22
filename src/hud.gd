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

extends Node

var hero: Actor
# TODO: use unique %name to simplify some of those
@onready var loot_button = find_child("LootButton")
@onready var stairs_button = find_child("StairsButton")
@onready var hplabel = find_child("HPLabel")
@onready var cheats_box = find_child("CheatsMargin")
@onready var dialogue_pane = %DialoguePane
@onready var actor_details_screen = %ActorDetailsScreen

func _ready():
	# only show the testing UI on debug builds
	var is_debug = Utils.is_debug()
	var rbar = find_child("RButtonBar")
	for node in rbar.get_children():
		if node is Button:
			node.visible = is_debug

func set_hero(hero_):
	hero = hero_
	hero.health_changed.connect(refresh_hps)
	hero.moved.connect(refresh_buttons_vis)
	refresh_hps()
	refresh_buttons_vis(null, hero.get_cell_coord())

func refresh_hps(_new_health=null):
	# TODO: bold animation when dead
	hplabel.text = "%2d" % hero.health

func _refresh_lbar_commands(hero_coord, index):
	## Remove commands that are no longer valid from the lbar and add the newly valid ones.
	# TODO: recycle as many buttons as possible rather than recreating everything.
	for node in %LButtonBar.get_children():
		if node is CommandButton:
			%LButtonBar.remove_child(node)
	for cmd in %CommandPack.commands_for(hero_coord, true, index):
		var btn = CommandButton.new(cmd, hero_coord)
		%LButtonBar.add_child(btn)

func update_states_at(hero_coord):
	## Refresh internal states by taking into account a recent change at `hero_coord`
	var board = hero.get_board()
	%CityMapButton.visible = board.world_loc != Consts.LOC_INVALID and board.world_loc.z >= 0
	if board.is_connector(hero_coord):
		stairs_button.visible = true
		if "gateway" == board.get_cell_terrain(hero_coord):
			stairs_button.text = "Follow Passage"
		else:
			stairs_button.text = "Follow Stairs"
	else:
		stairs_button.visible = false
	var index = board.make_index()
	loot_button.visible = null != index.top_item_at(hero_coord)
	refresh_cancel_button_vis()
	_refresh_lbar_commands(hero_coord, index)

func refresh_buttons_vis(_old_coord, hero_coord):
	## update the visibility of some action button depending on where the hero is standing
	update_states_at(hero_coord)

func refresh_cancel_button_vis():
	%CancelButton.visible = hero.has_strategy(true)

func _on_stairs_button_pressed():
	var event = InputEventAction.new()
	event.action = "follow-stairs"
	event.pressed = true
	Input.parse_input_event(event)

func toggle_cheats_box():
	cheats_box.visible = not cheats_box.visible

func show_action_label(text):
	$ActionLabel.text = text
	$ActionLabel.show()
	
func hide_action_label():
	$ActionLabel.hide()

func add_message(text):
	%MessagesPane.add_message(text)
	%MessagesScreen.add_message(text)

func refresh_input_enabled(enabled):
	if enabled:
		%WaitingLabel.hide()
	else:
		%WaitingLabel.show()

	if Tender.hero:
		var hero_coord = Tender.hero.get_cell_coord()
		var index = Tender.hero.get_board().make_index()
		_refresh_lbar_commands(hero_coord, index)

	for child in %LButtonBar.get_children():
		if child is Button:
			child.disabled = not enabled

func _on_hero_state_changed(new_state):
	refresh_input_enabled(new_state == Actor.States.LISTENING)


func _on_city_map_button_pressed():
	var board = Tender.hero.get_board()
	%CityMapScreen.popup(board.world_loc)
