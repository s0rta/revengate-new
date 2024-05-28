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

## Various utility functions that don't fit anywhere else.
class_name Utils extends Object

static func is_debug() -> bool:
	## Return whether we are in debug mode
	return Consts.DEBUG and OS.is_debug_build()

static func dstr_node(node:Node, show_owner:=true) -> String:
	## Return a string summary of a hiarchy of a node's children
	var lines = []
	var prefix = node.get_path().get_concatenated_names()
	for child in node.find_children("", "Node", true, false):
		var node_str = child.get_path().get_concatenated_names().replace(prefix, ".")
		if node_str.is_empty():
			node_str = child.name
		if show_owner:
			node_str += " owner=%s" % [child.get_owner()]
		lines.append(node_str)
	lines.append("")
	return "\n".join(lines)
	
static func dlog_node(node:Node, path:String, show_owner:=false):
	## Log basic infos about all the nodes in a tree to a file.
	var node_str = Utils.dstr_node(node, show_owner)
	FileAccess.open(path, FileAccess.WRITE).store_string(node_str)

static func dstr_properties(obj:Object) -> String:
	var lines = []
	for prop in obj.get_property_list():
		lines.append("%s" % [prop])
		lines.append("    %s" % [obj.get(prop.name)])
	lines.append("")
	return "\n".join(lines)

static func ddump_event(event, node, meth_name):
	## Print a trace that event was received by node.meth_name(). 
	## Note all events are printed, only those with high debug-value.
	if not event is InputEventMouseMotion:
		print("%s.%s(%s)" % [node.name, meth_name, event])

static func screen_size():
	## Return a rough approximation of the screen size in cm.
	## OS reporting is not accurate, so don't use this for anything mission 
	## critical.
	var pixels = DisplayServer.screen_get_size()
	var dpcm = 0.3937 * DisplayServer.screen_get_dpi()
	return pixels / dpcm

static func sum(values:Array):
	var total = 0
	for val in values:
		total += val
	return total

static func median(values:Array):
	assert(not values.is_empty())
	values = values.duplicate()
	values.sort()
	return values[len(values)/2]
	
static func percentile_breakdown(values:Array, k_nums:Array):
	## Returns elements of values based on k_nums percentiles in values
	## ex: k_nums could be [25, 50, 75], returns the p25, p50(median), and p75
	## elements of values 
	assert(not values.is_empty())
	var percentiles = []
	values = values.duplicate()
	values.sort()
	
	for k_num in k_nums:
		percentiles.append(values[(len(values) * k_num) / 100])
		
	return percentiles	

static func to_set(keys:Array) -> Dictionary:
	## Return a dict to be use as a set (each key marks set membership).
	## keys are set to `true`, you get test them with `set.has()` or `set.get()`.
	var set = {}
	for key in keys:
		set[key] = true
	return set

static func is_tag(str):
	return str in Consts.TAGS

static func assert_all_tags(strings:Array):
	for str in strings:
		assert(is_tag(str), "%s is not a valid tag name" % str)

static func filter_nodes_by_type(nodes, type_name):
	## Return a sub-list of `nodes` that are chidren of `type_name`
	# The ugly cascading if's is because node.get_class() and node.is_class() only return the 
	# built-in classes, they completely ignore the part of the hierarchy that is defined in 
	# GDScript. When selecting a subset of a node's children, Node.get_children() is better and 
	# it can adequately find nodes by their GDScript class_name.
	var right_type = func (node):
		if type_name == "Actor":
			return node is Actor
		elif type_name == "Item":
			return node is Item
		elif type_name == "Vibe":
			return node is Vibe
		else:
			assert(false, "Filtering by type '%s' is not implemented!" % [type_name])
	return nodes.filter(right_type)

static func _combine_modifiers(main_mods, sub_mods):
	## Combine all the values of `sub_mods` into `main_mods. Changes are done in-place.
	if sub_mods == null:
		return
	for key in Consts.CORE_STATS + Consts.CHALLENGES:
		var val = sub_mods.get(key)
		if val:
			main_mods[key] += val

static func get_node_modifiers(node:Node, valid_pred=null):
	## Return a dict of all the modifiers for a node
	## valid_pred: if supplied, only nodes for which the function returns `true` are considered
	var all_mods = {}
	for key in Consts.CORE_STATS + Consts.CHALLENGES:
		all_mods[key] = 0
	for child in node.get_children():
		# modifier can be on a `StatsModifiers` sub-node inside a `stats_modifiers` dict attribute
		if valid_pred and not valid_pred.call(child):
			continue
		if child.get("is_expired") and child.is_expired():
			continue
		if child is StatsModifiers:
			_combine_modifiers(all_mods, child)
		else:
			for sub_child in child.get_children():
				if valid_pred and not valid_pred.call(child):
					continue
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

static func path_join(a:String, b:String) -> String:
	## Return a joined path from `a` and `b`.
	## This is more or less like os.path.join() in Python
	if a.is_empty() or a.ends_with("/"):
		return a + b
	else:
		return a + "/" + b

static func path_join_all(parts:Array) -> String:
	var path = ""
	for part in parts:
		path = path_join(path, part)
	return path

static func remove_dir(path):
	## Remove a directory and all of its content
	## Only flat directories (no sub-dirs) are supported 
	# TODO: recursive process
	for f in DirAccess.get_files_at(path):
		var f_path = path_join(path, f)
		DirAccess.remove_absolute(f_path)
	var res = DirAccess.remove_absolute(path)
	assert(res==Error.OK, "Couldn't remove %s: %s" % [path, res])

static func wait_for_signal(sig):
	## Wait for a signal to be emited, return how long you waited in seconds
	var start = Time.get_unix_time_from_system()
	await sig
	var stop = Time.get_unix_time_from_system()
	return stop - start

static func hide_unplaced(node:Node2D):
	## Hide a node unless it's currently placed on a board.
	var parent = node.get_parent()
	if parent is Actor:
		node.shroud(false)
	if not parent is RevBoard:
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

static func time_str(seconds:float):
	var hours = seconds / 3600
	var minutes = fmod(seconds, 3600) / 60
	var only_seconds = fmod(seconds, 60)
	var parts = []
	if hours >= 1:
		parts.append("%d hours" % hours)
	if hours >= 1 or minutes >= 1:
		parts.append("%d minutes" % minutes)
	parts.append("%.1f seconds" % only_seconds)
	return " ".join(parts)

static func make_game_summary():
	var bullet = "🞙"
	if Tender.nb_cheats:
		bullet = "🞟"
	var kill_summary: String
	if Tender.kills.is_empty():
		kill_summary = "You didn't defeat any monsters."
	else:
		var lines = []
		var categories = Tender.kills.keys()
		categories.sort()
		for cat in categories:
			lines.append("%s %s: %s" % [bullet, cat, Tender.kills[cat]])
		kill_summary = "\n".join(lines)
	var cheats_line = ""
	if Tender.nb_cheats == 1:
		cheats_line = "You cheated once.\n\n"
	elif Tender.nb_cheats > 1:
		cheats_line = "You cheated %d times.\n\n" % Tender.nb_cheats
	var stats_lines = []
	for key in Tender.hero_stats:
		if Tender.hero_modifiers.get(key):
			stats_lines.append("%s %s:%s (%+d)" % [bullet, key, 
													Tender.hero_stats[key], 
													Tender.hero_modifiers[key]])
		else:
			stats_lines.append("%s %s:%s" % [bullet, key, Tender.hero_stats[key]])
	var stats_summary = "\n".join(stats_lines)
	return ("Your adventure lasted %d turns and took you through %d locations.\n\n"
			+ cheats_line
			+ "You played this game for %s.\n\n"
			+ "Monsters defeated:\n%s\n\n"
			+ "Character stats (modifiers):\n%s\n\n") % [Tender.last_turn, 
															Tender.seen_locs.size(), 
															time_str(Tender.play_secs),
															kill_summary, stats_summary]

static func has_tags(node, tags:Array):
	## Return whether `node` has all the provided tags
	## Return `true` when tags is empty
	if tags.is_empty():
		return true
	if node.get("tags") == null:
		return false
	for tag in tags:
		if not tag in node.tags:
			return false
	return true

static func has_any_tags(node, tags:Array):
	## Return whether `node` has any of the provided tags
	if node.get("tags") == null:
		return false
	for tag in tags:
		if tag in node.tags:
			return true
	return false

static func add_tag(node, tag:String):
	## Add a tag from to a node
	assert(is_tag(tag))
	# The `tags` array is shared across all instance of the same node type at 
	# creation. We have to make a copy to prevent all the other nodes from 
	# receiving the new tag as well.
	node.tags = node.tags.duplicate()
	node.tags.append(tag)

static func remove_tag(node, tag:String):
	assert(is_tag(tag))
	# The `tags` array is shared across all instance of the same node type at 
	# creation. We have to make a copy to prevent all the other nodes from 
	# also losing the removed tag.
	node.tags = node.tags.duplicate()
	node.tags.erase(tag)

static func has_spawn_tags(node):
	## Return whether `node` has spawn constraint tags
	var tags = node.get("tags")
	if tags == null:
		return false
	for tag in tags:
		if tag.begins_with("spawn"):
			return true
	return false

static func spawn_tags(node):
	## Return spawn constraint tags for `node`
	var spawn_tags = []
	var tags = node.get("tags")
	if tags == null:
		return []
	for tag in tags:
		if tag.begins_with("spawn"):
			spawn_tags.append(tag)
	return spawn_tags	

static func effect_path(sfx_name):
	## Return the path of a special effect
	return "res://src/sfx/%s.tscn" % sfx_name

static func tags_eq(tags1, tags2):
	## Return whether two Array of tags are the same.
	if len(tags1) != len(tags2):
		return false
	tags1 = tags1.duplicate()
	tags1.sort()
	tags2 = tags2.duplicate()
	tags2.sort()
	return tags1 == tags2

static func ddump_call(funct:Callable):
	## Call `funct` and print how long the execution took in real time.
	## Return the value of the funct() call.
	var start = Time.get_ticks_msec()
	var ret = funct.call()
	var elapsed = (Time.get_ticks_msec() - start) / 1000.0
	print("Execution of %s took %0.3f seconds" % [funct, elapsed])
	return ret

static func vague_value(value, place_in_range, perception) -> String:
	## Return a string that describes `value` according to a given `perception` level.
	## `place_in_range`: 0..1 ranking of `value` in its possible range. Can't be out of 0..1
	##    for exceptional values.
	var descpitors:Array
	var value_str:String
	if is_instance_of(value, TYPE_FLOAT):
		value_str = "%0.3f" % value
	else:
		value_str = "%s" % value
		
	if perception >= Consts.PERFECT_PERCEPTION:
		# you see the value rather than a descriptor when you are that perceptive
		return value_str
	elif perception >= Consts.GREAT_PERCEPTION:
		descpitors = ["excellent", "good", "average", "mediocre", "feeble"]
	elif perception > Consts.INEPT_PERCEPTION:
		descpitors = ["solid", "good", "weak", "very weak"]
	elif Tender.vague_vals_cache.has(value_str): 
		return Tender.vague_vals_cache[value_str]
	else:
		# you are too unperceptive to know if a value is good or not, so you get a random
		# descriptor
		var very_vague_adjs = ["considerable", "substantial", "real", "so so", 
								"wow!", "medium", "legit", "meh"]
		var adj = Rand.choice(very_vague_adjs)
		Tender.vague_vals_cache[value_str] = adj
		return adj

	var bounds = []
	for i in len(descpitors):
		bounds.append(i*1.0/len(descpitors))
	bounds.reverse()
		
	for i in len(descpitors):
		if place_in_range >= bounds[i]:
			return descpitors[i]
	
	# smaller than the normal range
	return descpitors[-1]
	
static func event_is_tap_or_left(event):
	if event is InputEventScreenTouch:
		return true
	if not OS.has_feature("mobile"):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			return true
	return false
	
static func adjust_lights_settings(node:Node):
	## Match the light properties to what we have in the saved Tabulator settings
	var tab := Tabulator.load()
	for light in node.find_children("", "Light2D", false, false):
		if tab.dyn_lights == Consts.Lights.NONE:
			light.enabled = false
		elif tab.dyn_lights == Consts.Lights.HARD_SHADOWS:
			light.enabled = true
			if light.shadow_enabled:
				light.shadow_filter = Light2D.SHADOW_FILTER_NONE
		elif tab.dyn_lights == Consts.Lights.SOFT_SHADOWS:
			light.enabled = true
			if light.shadow_enabled:
				light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
				light.shadow_filter_smooth = 18
