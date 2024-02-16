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

extends Node

signal cancel_strategies

# TODO: use unique %name to simplify some of those
@onready var loot_button = find_child("LootButton")
@onready var stairs_button = find_child("StairsButton")
@onready var cheats_box = find_child("CheatsMargin")
@onready var dialogue_pane = %DialoguePane
@onready var actor_details_screen = %ActorDetailsScreen
var quick_attack_cmd : CommandPack.Command 

func _ready():
	# only show the testing UI on debug builds
	var is_debug = Utils.is_debug()
	var tabulator = Tabulator.load()
	%TestButton1.visible = is_debug
	%TestButton2.visible = is_debug
	%ShowCheatsButton.visible = is_debug or tabulator.allow_cheats

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		if Tender.hero.has_strategy(true):
			get_viewport().set_input_as_handled()
			request_cancel_strats()

func get_gesture_surveyor():
	return $/root.find_child("GestureSurveyor", true, false)

func watch_hero(hero:Actor=null):
	## Connect UI elements like the health-bar to keep track of `hero`.
	if hero == null:
		if Tender.hero != null:
			hero = Tender.hero
		else:
			return  # not much we can do under a hero has been initialized
	hero.moved.connect(refresh_buttons_vis)
	hero.changed_weapons.connect(_on_hero_changed_weapons)
	hero.dropped_item.connect(_set_quick_attack_icon)
	hero.dropped_item.connect(update_states_at_hero)
	hero.picked_item.connect(_set_quick_attack_icon)
	hero.picked_item.connect(update_states_at)
	hero.state_changed.connect(_on_hero_state_changed)
	hero.strategy_expired.connect(refresh_cancel_button_vis)
	hero.health_changed.connect(refresh_hps)
	refresh_hps()
	refresh_buttons_vis(null, hero.get_cell_coord())
	
	var index = hero.get_board().make_index()
	quick_attack_cmd = CommandPack.QuickAttack.new(index)
	_set_quick_attack_icon()

func _set_quick_attack_icon(_arg=null):
	var weapons = Tender.hero.get_weapons()
	assert(len(weapons) == 1, "Dual weilding is not implemented for QuickAttack button style")
	var weapon = weapons[0]
	%QuickAttackButton.text = weapon.char
	if "groupable" in weapon.tags:
		var nb = len(Tender.hero.get_compatible_items(weapon))
		if nb >= 1:
			%QuickAttackButton.text += "x%d" % (nb+1)

func refresh_hps(_new_health=null):
	%HealthMeter.value_full = Tender.hero.health_full
	%HealthMeter.set_value(Tender.hero.health)

func _refresh_lbar_commands(hero_coord, index):
	## Remove commands that are no longer valid from the lbar and add the newly valid ones.
	# TODO: recycle as many buttons as possible rather than recreating everything.
	for node in %LButtonBar.get_children():
		if node is CommandButton:
			%LButtonBar.remove_child(node)
	for cmd in %CommandPack.commands_for(hero_coord, true, index):
		if not cmd.is_cheat and not cmd.is_debug:
			var btn = CommandButton.new(cmd, hero_coord, true)
			%LButtonBar.add_child(btn)

func _refresh_cheatsbar_commands(hero_coord, index):
	## Remove commands that are no longer valid from the cheats bar and add the newly valid ones.
	# TODO: recycle as many buttons as possible rather than recreating everything.
	for node in %CheatsBar.get_children():
		if node is CommandButton or node is Button:
			%CheatsBar.remove_child(node)
	var is_debug = Utils.is_debug()
	for cmd in %CommandPack.commands_for(hero_coord, true, index):
		if cmd.is_cheat or is_debug and cmd.is_debug:
			var btn = CommandButton.new(cmd, hero_coord, true)
			%CheatsBar.add_child(btn)

func update_states_at(hero_coord):
	## Refresh internal states by taking into account a recent change at `hero_coord`
	var board = Tender.hero.get_board()
	%CityMapButton.visible = board.world_loc != Consts.LOC_INVALID and board.world_loc.z >= 0
	refresh_quest_btn()
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
	_refresh_cheatsbar_commands(hero_coord, index)

func update_states_at_hero(_arg=null):
	update_states_at(Tender.hero.get_cell_coord())

func refresh_buttons_vis(_old_coord, hero_coord):
	## update the visibility of some action button depending on where the hero is standing
	update_states_at(hero_coord)

func refresh_cancel_button_vis():
	var has_strat = Tender.hero.has_strategy(true)
	%CancelButton.visible = has_strat
	%CancelButton2.visible = has_strat

func refresh_quest_btn():
	%ShowQuestLogButton.disabled = not Tender.quest.is_active

func _on_stairs_button_pressed():
	var event = InputEventAction.new()
	event.action = "follow-stairs"
	event.pressed = true
	Input.parse_input_event(event)

func toggle_cheats_box():
	cheats_box.visible = not cheats_box.visible

func show_action_label(text):
	%ActionLabel.text = text
	%ActionLabel.show()
	
func hide_action_label():
	%ActionLabel.hide()

func add_message(text:String, 
				level:Consts.MessageLevels, 
				tags:Array[String]):
	if "strategy" in tags:
		if %ProminentMsgLabel.text.is_empty():
			%ProminentMsgLabel.text = text
		else:
			%ProminentMsgLabel.text = "%s\n%s" % [%ProminentMsgLabel.text, text]
		%ProminentMsgLabel.show()
	else:
		%MessagesPane.add_message(text, level, tags)
		%MessagesScreen.add_message(text, level, tags)

func refresh_input_enabled(enabled):
	if enabled:
		%WaitingLabel.hide()
		%ProminentMsgLabel.hide()
	else:
		%WaitingLabel.show()

	if Tender.hero:
		var hero_coord = Tender.hero.get_cell_coord()
		var index = Tender.hero.get_board().make_index()
		_refresh_lbar_commands(hero_coord, index)
		_refresh_cheatsbar_commands(hero_coord, index)
		
	for child in %LButtonBar.get_children():
		if child is Button:
			child.disabled = not enabled

func request_cancel_strats():
	cancel_strategies.emit()

func _on_hero_state_changed(new_state):
	if Tender.hero == null:
		# not fully initialized, can't do anything too fancy yet
		return
	if new_state != Actor.States.IDLE:
		%ProminentMsgLabel.text = ""
	refresh_input_enabled(new_state == Actor.States.LISTENING)
	if new_state == Actor.States.LISTENING:
		quick_attack_cmd.refresh(Tender.hero.get_board().make_index())
		var here = Tender.hero.get_cell_coord()
		%QuickAttackButton.disabled = not quick_attack_cmd.is_valid_for_hero_at(here)
	else:
		%QuickAttackButton.disabled = true

func _on_city_map_button_pressed():
	var board = Tender.hero.get_board()
	%CityMapScreen.popup(board.world_loc)

func _on_quick_attack_button_button_up():
	print("Attacking someone else real quick...")
	if quick_attack_cmd.run_at_hero(Tender.hero.get_cell_coord()):
		Tender.hero.finalize_turn(true)

func _on_hero_changed_weapons():
	_set_quick_attack_icon()

func _on_show_quest_log_button_button_up():
	if not Tender.quest.is_active:
		print("Quest is inactive")
	else:
		Tender.hero.add_message(Tender.quest.summary, Memory.Importance.CRUCIAL)

func _on_dialogue_pane_quest_activated():
	refresh_quest_btn()

func _on_center_control_visibility_changed():
	%CenterPanel.visible = (%ActionLabel.visible
							or %WaitingLabel.visible
							or %ProminentMsgLabel.visible
							or %CancelButton2.visible)

