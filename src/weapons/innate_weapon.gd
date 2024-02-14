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

## Like a Weapon as far as attacking goes, but not part of the inventory mechanics.
## A typical example is a body part.
@icon("res://assets/opencliparts/cayenne.svg")
class_name InnateWeapon extends Node

@export var char := "🥊"
@export var damage := 1
@export var damage_family: Consts.DamageFamily
@export var range := 1
@export_range(0.0, 1.0) var probability := 1.0
@export var tags:Array[String]
var has_effect := false

# You can't change which skill is checked, but that skill can be trained. To improve it, 
# add a SkillLevels sub-node on the actor.
const skill := "innate_attack"

func _ready():
	has_effect = not find_children("", "Effect", false, false).is_empty()
