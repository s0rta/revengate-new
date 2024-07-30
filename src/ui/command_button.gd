# Copyright © 2023–2024 Yannick Gingras <ygingras@ygingras.net> and contributors

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

## A Button specifically made to run a CommandPack.Command
class_name CommandButton extends Button

var cmd:CommandPack.Command
var coord:Vector2i
var hero_pov:bool

func _init(command, coord_, hero_pov_:bool):
	focus_mode = Control.FOCUS_NONE
	cmd = command
	coord = coord_
	hero_pov = hero_pov_
	text = command.caption
	if cmd.is_action:
		theme_type_variation = "ActionBtn"
	button_up.connect(on_button_up)

func _shortcut_input(event):
	if disabled:
		return
	if cmd.ui_action and event.is_action_pressed(cmd.ui_action):
		accept_event()
		pressed.emit()
		on_button_up()

func reset_visibility(coord_:Vector2i, index:RevBoard.BoardIndex):
	coord = coord_
	cmd.index = index
	if hero_pov:
		visible = cmd.is_valid_for_hero_at(coord)
	else:
		visible = cmd.is_valid_for(coord)
	text = cmd.caption

func on_button_up():	
	var acted: bool
	if hero_pov:
		acted = await cmd.run_at_hero(coord)
	else:
		acted = await cmd.run(coord)
		
	if acted:
		Tender.hero.finalize_turn(acted)
