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
@tool
@icon("res://assets/opencliparts/flame_warning.svg")
## An effect that can result in a damage-over-time condition
class_name Effect extends Node

const BAD_NAME_MSG = "Effects that leave a Condition on the actor need a condtion_name!"

@export_group("Presentation")
@export var condition_name := ""

@export_group("Health Changes")
@export var damage := 0
# healing could also be expressed as a negative damage, but positive numbers are more intuitive
@export var healing := 0
@export var damage_family := Consts.DamageFamily.NONE

@export_group("Stats Modifiers")
@export var strength := 0
@export var agility := 0
@export var intelligence := 0
@export var perception := 0
@export var health_full := 0
@export_range(0, 1) var healing_prob := 0.0
@export_range(0.0, 1.0) var mana_recovery_prob := 0.0

@export_group("Applicability")
@export_range(0, 1) var probability := 1.0  # chance that the effect will be applied
@export var immediate := false
@export var nb_turns := 1
@export var permanent := false  # ignores immediate and damage_family

@export_group("Tagging")
@export var tags:Array[String]

func _get_configuration_warnings():
	var warnings = []
	if permanent:
		if nb_turns != 0:
			warnings.append("Permanent effects can't specify nb_turns!")
		if damage != 0 or healing != 0:
			warnings.append("Permanent effects can only affect core stats, not provide damage or healing!")
	if not cond_name_is_valid():
		warnings.append(BAD_NAME_MSG)
	return warnings

func _ready():
	assert(cond_name_is_valid(), BAD_NAME_MSG)

func apply(actor):
	## Apply the effect to `actor`. 
	## If `probability` < 1, this could be a no-op.
	## If `immediate`, the effect starts this turn, otherwise, the effect start 
	##   at the beginning of the next turn.
	if not Rand.rstest(probability):
		return
	var mods = CombatUtils.node_core_stats(self)
	if permanent:
		perma_boost(actor, mods)
	else:
		var dkind = "%sCond" % [name]
		var cond = Condition.new(dkind, condition_name, damage, healing, damage_family, tags, nb_turns)
		cond.stats_modifiers = mods
		cond.owner = null
		actor.add_child(cond)
		if immediate:
			cond.erupt()

func perma_boost(actor:Actor, modifiers):
	for key in modifiers:
		var new_val = actor.get(key) + modifiers[key]
		actor.set(key, new_val)
		
func cond_name_is_valid() -> bool:
	## Return whether the condition name is valid.
	## The effect needs a condition name if it can leave an Inspectable condition on the actor:
	##  - non-permanent
	##  - nb_turns > 1
	if permanent or nb_turns < 1:
		return true
	elif immediate and nb_turns == 1:
		return true
	else:
		return not condition_name.is_empty()
	
