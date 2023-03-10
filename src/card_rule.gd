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

@tool
@icon("res://assets/opencliparts/whistle.svg")
## A rule to determine when we can add our children cards to a generation deck
class_name CardRule extends Node

# TODO: min_* rules can default to 0 rather than -1
@export var min_depth:int = 0
@export var max_depth:int = -1
@export var max_board_occ:int = -1
@export var max_dungeon_occ:int = -1

# applied by forcing those cards in the mandatory deck for a floor
@export var min_board_occ:int = 0
@export var min_dungeon_occ:int = 0

func _get_configuration_warnings():
	var warnings = []
	if min_depth < 0:
		warnings.append("`min_depth` should not be negative")
	if min_dungeon_occ and max_depth == -1:
		warnings.append("You must specify `max_depth` for `min_dungeon_occ` to have an effect.")
	return warnings
