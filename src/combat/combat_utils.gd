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

class_name CombatUtils extends Object

static func node_core_stats(node):
	## Return the node core combat stats as a dict.
	## This only works for nodes that store core stats as direct attributes, 
	##   like Actor and Effect.
	if node == null:
		return {}
	var mods = {}
	for key in Consts.CORE_STATS + Consts.CHALLENGES:
		var val = node.get(key)
		if val:
			mods[key] = val
	return mods

static func skill_modifier(level:Consts.SkillLevel):
	return 5 * level

static func apply_all_effects(weapon, victim):
	for node in weapon.get_children():
		if node is Effect:
			node.apply(victim)

static func as_coord(thing):
	## Return the board coordinates of `thing`
	if thing is Vector2i:
		return thing
	elif thing is Actor or thing is Item or thing is Vibe:
		return thing.get_cell_coord()
	else:
		assert(false, "Don't know how to get board coordinates of %s" % thing)

static func add_kill(actor_type):
	## Increment the kill count for a given actor type
	if not Tender.kills.has(actor_type):
		Tender.kills[actor_type] = 0
	Tender.kills[actor_type] += 1

static func are_peers(actor_a, actor_b):
	## Return if two actors are similar enough to be considerer "related" or "peers".
	# This currently a very rough approximation that is prone to false positives. 
	# Using classifier tags would be more robust.
	return (actor_b != actor_a 
			and actor_b.char == actor_a.char 
			and actor_b.faction == actor_a.faction)
