# Copyright © 2023 Yannick Gingras <ygingras@ygingras.net> and contributors

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

func _init(command, coord_):
	cmd = command
	coord = coord_
	text =  command.caption
	if cmd.is_action:
		theme_type_variation = "ActionBtn"
	button_up.connect(on_button_up)

func on_button_up():
	# DEBUG
	cmd.index = Tender.hero.get_board().make_index()
	assert(cmd.is_valid_for_hero_at(coord))
	
	var acted = cmd.run_at_hero(coord)
	if acted:
		Tender.hero.finalize_turn(acted)
	if not cmd.is_valid_for_hero_at(coord):
		queue_free()
