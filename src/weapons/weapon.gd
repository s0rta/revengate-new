# Copyright © 2022–2023 Yannick Gingras <ygingras@ygingras.net> and contributors

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

@icon("res://assets/opencliparts/sword_01.svg")
class_name Weapon extends Item

@export var damage := 1
@export var range := 1  # number of effective tile for an average thwrower (strength=50)
@export var damage_family: Consts.DamageFamily
@export var is_equipped := false
var has_effect := false

func _ready():
	super()
	has_effect = not find_children("", "Effect", false, false).is_empty()

func get_base_stats():
	## Return a dictionnary of the core stats without any modifiers applied
	var stats = {}
	for name in Consts.WEAPON_BASE_STATS:
		stats[name] = get(name)
	return stats
