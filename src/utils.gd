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

static func is_debug() -> bool:
	## Return whether we are in debug mode
	return Consts.DEBUG and OS.is_debug_build()

static func ddump_event(event, node, meth_name):
	## Print a trace that event was received by node.meth_name(). 
	## Note all events are printed, only those with high debug-value.
	if not event is InputEventMouseMotion:
		print("%s.%s(%s)" % [node.name, meth_name, event])

static func is_tag(str):
	return str in Consts.TAGS

static func assert_all_tags(strings:Array):
	for str in strings:
		assert(is_tag(str), "%s is not a valid tag name" % str)

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

static func wait_for_signal(sig):
	## Wait for a signal to be emited, return how long you waited in seconds
	var start = Time.get_unix_time_from_system()
	await sig
	var stop = Time.get_unix_time_from_system()
	return stop - start

static func hide_unplaced(node:Node2D):
	## Hide a node unless it's currently placed on a board.
	if not node.get_parent() is RevBoard:
		node.hide()

static func shroud_node(node:Node2D, animate=true):
	## Change the display of a node to make it hardly (or not) perceiveable for the player.
	if node.shrouded:
		return  # nothing to do
	if node._shroud_anim:
		node._shroud_anim.kill()
	node.shrouded = true
	if animate:
		node._shroud_anim = node.get_tree().create_tween()
		node._shroud_anim.tween_property(node, "modulate", Consts.FADE_MODULATE, Consts.FADE_DURATION)
	else:
		node._shroud_anim = null
		node.modulate = Consts.FADE_MODULATE

static func unshroud_node(node:Node2D, animate=true):
	## Change the display of a node to make it normally visible to the player
	if not node.shrouded:
		return  # nothing to do
	if node._shroud_anim:
		node._shroud_anim.kill()
	node.shrouded = false
	if animate:
		node._shroud_anim = node.get_tree().create_tween()
		node._shroud_anim.tween_property(node, "modulate", Consts.VIS_MODULATE, Consts.FADE_DURATION)
	else:
		node._shroud_anim = null
		node.modulate = Consts.VIS_MODULATE

static func fadeout_later(node:Node, nb_secs:float, free:=true):
	## Do a fadeout animation on `node` after `nb_secs`.
	## If `free`, the node is deleted after the fadeout.
	var timer = node.get_tree().create_timer(nb_secs)
	await timer.timeout
	var col = Color(node.modulate)
	col.a = 0.0
	var anim = node.get_tree().create_tween()
	anim.tween_property(node, "modulate", col, 0.5)
	await anim.finished
	node.hide()
	if free:
		node.queue_free()

static func make_game_summary():
	print("hero is: %s" % Tender.hero)
	var kill_summary: String
	if Tender.kills.is_empty():
		kill_summary = "You didn't defeat any monsters."
	else:
		var lines = []
		var categories = Tender.kills.keys()
		categories.sort()
		for cat in categories:
			lines.append("%s: %s" % [cat, Tender.kills[cat]])
		kill_summary = "[ul]%s[/ul]" % ["\n".join(lines)]
	var stats_lines = []
	for key in Tender.hero_stats:
		if Tender.hero_modifiers.get(key):
			stats_lines.append("[ul]%s:%s (%+d)[/ul]" % [key, Tender.hero_stats[key], Tender.hero_modifiers[key]])
		else:
			stats_lines.append("[ul]%s:%s[/ul]" % [key, Tender.hero_stats[key]])
	var stats_summary = "\n".join(stats_lines)
	return ("Your adventure lasted %d turns and took you through %d locations.\n\n" 
			+ "[b]Monsters defeated[/b]\n%s\n\n"
			+ "[b]Character stats (modifiers)[/b]\n%s") % [Tender.last_turn, Tender.nb_locs, 
															kill_summary, stats_summary]
