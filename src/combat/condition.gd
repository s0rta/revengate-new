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
@export var condition_name: String  # shown to the player
@export var damage: int
@export var healing: int
@export var damage_family: Consts.DamageFamily
@export var nb_turns: int
@export var stats_modifiers: Dictionary
@export var tags:Array[String]

func _init(dkind_:="", condition_name_:="", 
			damage_=0, healing_=0, damage_family_=Consts.DamageFamily.NONE, 
			tags_:Array[String]=[], nb_turns_=0):
	name = dkind_  # might be overriden before _ready() if there is a name clash with our siblings
	dkind = dkind_
	condition_name = condition_name_
	damage = damage_
	healing = healing_
	damage_family = damage_family_
	tags = tags_.duplicate()
	nb_turns = nb_turns_

func _to_string():
	# TODO: include the summary of mods
	return "<%s %s dmg=%d heal=%d, turns=%d>" % [name, condition_name, damage, healing, nb_turns]
	
func summary(percep_lvl:Consts.PercepLevel) -> String:
	assert(percep_lvl in Consts.PercepLevel.values())
	
	if percep_lvl <= Consts.PercepLevel.INEPT:
		return ""
	elif percep_lvl == Consts.PercepLevel.WEAK:
		return condition_name

	var turns_str:String
	if nb_turns < 1 or percep_lvl < Consts.PercepLevel.PERFECT:
		turns_str = ""
	elif nb_turns == 1:
		turns_str = "last turn"
	else:
		turns_str = "%d turns left" % nb_turns
	
	var deltas = []
	for key in ["healing", "damage"]:
		var val = get(key)
		if val:
			deltas.append("%s: %s" % [key, val])
	var modstrs = UIUtils.format_modifiers(stats_modifiers)
	var keys = modstrs.keys()
	keys.sort()
	for stat in keys:
		if percep_lvl == Consts.PercepLevel.NORMAL:
			deltas.append("%s%s" % [" +-"[sign(stats_modifiers[stat])], stat])
		else:
			deltas.append("%s: %s" % [stat, modstrs[stat]])
	var parts = deltas.duplicate()
	if turns_str:
		parts.append(turns_str)	
	return "%s (%s)" % [condition_name, ", ".join(parts)]

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
