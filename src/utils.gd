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

## Various utility functions that don't fit anywhere else.
class_name Utils extends Object

static func ddump_event(event, node, meth_name):
	## Print a trace that event was received by node.meth_name(). 
	## Note all events are printed, only those with high debug-value.
	if not event is InputEventMouseMotion:
		print("%s.%s(%s)" % [node.name, meth_name, event])

static func _combine_modifiers(main_mods, sub_mods):
	## Combine all the values of `sub_mods` into `main_mods. Changes are done in-place.
	if sub_mods == null:
		return
	for key in Consts.CORE_STATS + Consts.CHALLENGES:
		var val = sub_mods.get(key)
		if val:
			main_mods[key] += val

static func get_node_modifiers(node:Node):
	## return a dict of all the modifiers for a node
	var all_mods = {}
	for key in Consts.CORE_STATS + Consts.CHALLENGES:
		all_mods[key] = 0
	for child in node.get_children():
		# modifier can be on a `StatsModifiers` sub-node inside a `stats_modifiers` dict attribute
		if child is StatsModifiers:
			_combine_modifiers(all_mods, child)
		else:
			for sub_child in child.get_children():
				if sub_child is StatsModifiers:
					_combine_modifiers(all_mods, sub_child)
		_combine_modifiers(all_mods, child.get("stats_modifiers"))
	return all_mods

static func _combine_skills(main_skills, sub_skills):
	## Combine all the values of `sub_skills` into `main_skills. Changes are done in-place.
	if sub_skills == null:
		return
	for key in Consts.SKILLS:
		var val = sub_skills.get(key)
		if val:
			var old_val = main_skills.get(key, Consts.SkillLevel.NEOPHYTE)
			main_skills[key] = max(old_val, val) 

static func get_node_skills(node:Node):
	## return a dict of all the skill values for a node
	var all_skills = {}
	for child in node.get_children():
		# modifier can be on a `SkillLevels` sub-node inside a `skills_modifiers` dict attribute
		if child is SkillLevels:
			_combine_skills(all_skills, child)
		else:
			for sub_child in child.get_children():
				if sub_child is SkillLevels:
					_combine_skills(all_skills, sub_child)
		_combine_skills(all_skills, child.get("skills_modifiers"))
	return all_skills

static func colored(text):
	## Return `text` surrouded by ANSI escape sequences to make it print in 
	## color in a supported terminal.

	# Those should be consts, but the compiler does not like String.chr()
	var ESC_FMT = String.chr(27) + "[%dm"
	var ESC_MAG = ESC_FMT % 35
#	var ESC_CYAN = ESC_FMT % 36
	var ESC_RESET = ESC_FMT % 0

	return "%s%s%s" % [ESC_MAG, text, ESC_RESET]
