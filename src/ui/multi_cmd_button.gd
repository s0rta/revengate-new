# Copyright © 2024 Yannick Gingras <ygingras@ygingras.net> and contributors

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

@tool
## A button that can trigger two Commands (one on tap/left-click, one on long-tap/right-click)
class_name MultiCmdButton extends VBoxContainer

# TODO:
# - left-click
# - custom editor icon
# - hide progress bar when there is no alt-action

@export var text: String
@export var cmd_label: String
@export var alt_cmd_label: String
@export var hero_pov := true

@onready var timer := Timer.new()
@onready var progress_bar := ProgressBar.new()
@onready var btn := Button.new()

var cmd: CommandPack.Command
var alt_cmd: CommandPack.Command

func _ready():
	add_child(timer)
	grow_horizontal = GROW_DIRECTION_BOTH
	grow_vertical = GROW_DIRECTION_BOTH
	size_flags_horizontal = SIZE_SHRINK_CENTER & SIZE_EXPAND

	timer.wait_time = UIUtils.LONG_TAP_SECS
	timer.one_shot = true
	timer.timeout.connect(_on_timeout)

	progress_bar.mouse_filter = MOUSE_FILTER_IGNORE
	progress_bar.show_percentage = false
	add_child(progress_bar)

	btn.theme_type_variation = "ProminentButton"
	btn.focus_mode = FOCUS_NONE
	btn.size_flags_horizontal = SIZE_SHRINK_CENTER
	btn.text = text
	btn.button_down.connect(_on_button_down)
	btn.button_up.connect(_on_button_up)
	add_child(btn)

func _process(_delta):
	if not timer.is_stopped():
		var progress_ratio = (timer.wait_time - timer.time_left) / timer.wait_time
		progress_bar.value = 100.0 * progress_ratio

func resolve_commands(command_pack:CommandPack, index):
	## Instanciate primary and alt commands, should be called before our parent
	## is considered ready.
	var names:Array[String] = [cmd_label]
	if alt_cmd_label:
		names.append(alt_cmd_label)
	var cmds = command_pack.get_commands(names, index)
	cmd = cmds[cmd_label]
	if alt_cmd_label:
		alt_cmd	= cmds[alt_cmd_label]

func refresh(index:RevBoard.BoardIndex):
	## Refresh the index and state of all commands.
	## This should be called before set_enabled()
	for command in [cmd, alt_cmd]:
		if command != null:
			command.refresh(index)

func set_enabled(req_val:=true):
	## Make this button enabled or disabled.
	## For the button to be enabled, req_val must be true and one of the commands
	## must be valid at the current coord.
	## If req_val is not provided, only the validity of commands is considered.

	var val:bool
	if hero_pov:
		var coord = Tender.hero.get_cell_coord()
		val = req_val and cmd.is_valid_for_hero_at(coord)
	else:
		assert(false, "not implemented")
		#val = req_val and cmd.is_valid_for(coord)
	if req_val and not val and alt_cmd != null:
		# force enable if alt_cmd is valid
		if hero_pov:
			var coord = Tender.hero.get_cell_coord()
			val = alt_cmd.is_valid_for_hero_at(coord)
		else:
			assert(false, "not implemented")
			#val = req_val and alt_cmd.is_valid_for(coord)
	btn.disabled = not val

func reset_visibility(coord, index:RevBoard.BoardIndex):
	cmd.index = index
	if hero_pov:
		visible = cmd.is_valid_for_hero_at(coord)
	else:
		visible = cmd.is_valid_for(coord)

	if alt_cmd != null:
		alt_cmd.index = index
		if hero_pov:
			visible |= alt_cmd.is_valid_for_hero_at(coord)
		else:
			visible |= alt_cmd.is_valid_for(coord)

func _on_button_down():
	timer.stop()
	timer.start()
	progress_bar.modulate.a = 1

func _on_button_up():
	var has_run_alt = timer.is_stopped()
	timer.stop()
	progress_bar.modulate.a = 0
	if not has_run_alt:
		run()

func _on_timeout():
	progress_bar.modulate.a = 0
	run(true)

func run(alt:=false):
	var command = cmd
	if alt:
		command = alt_cmd
	var acted: bool
	if hero_pov:
		# FIXME: the command should find the hero, not the button
		var coord = Tender.hero.get_cell_coord()
		acted = command.run_at_hero(coord)
	else:
		assert(false, "not implemented")
		#acted = await command.run(coord)

	if acted:
		Tender.hero.finalize_turn(acted)
