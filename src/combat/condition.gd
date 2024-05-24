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

## The materialization of an effect. 
## Do not create those directly, let Effect do the instantiation.
class_name Condition extends Node

@export var dkind: String  # Debug Kind, never shown to the player
@export var damage: int
@export var healing: int
@export var damage_family: Consts.DamageFamily
@export var nb_turns: int
@export var stats_modifiers: Dictionary
@export var tags:Array[String]

func _init(dkind_:String="", damage_=0, healing_=0, damage_family_=Consts.DamageFamily.NONE, 
			tags_:Array[String]=[], nb_turns_=0):
	name = dkind_  # might be overriden before _ready() if there is a name clash with our siblings
	dkind = dkind_
	damage = damage_
	healing = healing_
	damage_family = damage_family_
	tags = tags_.duplicate()
	nb_turns = nb_turns_

func _to_string():
	return "<%s %s dmg=%d heal=%d, turns=%d>" % [name, dkind, damage, healing, nb_turns]
	
func erupt():
	## activate the condition
	var actor = get_parent()
	assert(actor is Actor, "Conditions can only erupt after being attached to an actor")
	# TODO: there could be a case for randomizing the damage from conditions
	var h_delta = healing - damage
	if h_delta != 0:
		h_delta = actor.normalize_health_delta(self, h_delta)
		actor.update_health(h_delta)
	decay()
	
func decay():
	nb_turns -= 1
	if nb_turns <= 0:
		queue_free()
