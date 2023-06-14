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

@icon("res://assets/opencliparts/flame_warning.svg")
## An effect that can result in a damage-over-time condition
class_name Effect extends Node

@export var damage := 0
# healing could also be expressed as a negative damage, but positive numbers are more intuitive
@export var healing := 0
@export var damage_family := Consts.DamageFamily.NONE
@export var strength := 0
@export var agility := 0
@export var intelligence := 0
@export var perception := 0
@export_range(0, 1) var probability := 1.0  # chance that the effect will be applied
@export var immediate := false
@export var nb_turns := 1
@export var magical := false  # various effect are more powerful for magical items

class Condition extends Node:
	var damage: int
	var healing: int
	var damage_family: Consts.DamageFamily
	var magical: bool
	var nb_turns: int
	var stats_modifiers: Dictionary

	func _init(damage_, healing_, damage_family_, magical_, nb_turns_):
		damage = damage_
		healing = healing_
		damage_family = damage_family_
		magical = magical_
		nb_turns = nb_turns_
		
	func erupt():
		## activate the condition
		var actor = get_parent()
		assert(actor is Actor, "Conditions can only erupt after being attached to an actor")
		# TODO: there could be a case for randomizing the damage from conditions
		var h_delta = healing - damage
		h_delta = actor.normalize_health_delta(self, h_delta)
		actor.update_health(h_delta)
		decay()
		
	func decay():
		nb_turns -= 1
		if nb_turns <= 0:
			queue_free()
	
func apply(actor):
	## Apply the effect to `actor`. 
	## If `probability` < 1, this could be a no-op.
	## If `immediate`, the effect starts this turn, otherwise, the effect start 
	##   at the beginning of the next turn.
	if not Rand.rstest(probability):
		return
	var cond = Condition.new(damage, healing, damage_family, magical, nb_turns)
	cond.stats_modifiers = CombatUtils.node_core_stats(self)
	actor.add_child(cond)
	if immediate:
		cond.erupt()
