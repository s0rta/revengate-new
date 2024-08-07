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

class_name SummonPhantruch extends Spell

const PHATRUCH_SCENES = ["res://src/monsters/phantruch-lesser.tscn", 
						"res://src/monsters/phantruch-higher.tscn"]

func _ready():
	super()
	mana_cost = 10
	tags.append("summoning")

func has_reqs():
	if not super():
		return false
	return not me.get_items(["vital-assemblage"], ["broken"]).is_empty()

func get_creature_path():
	# Expert casters can summon the whole cast, otherwise, only the first creature is available.
	if me.get_skill("channeling") < Consts.SkillLevel.EXPERT:
		return PHATRUCH_SCENES[0]
	else:
		return Rand.choice(PHATRUCH_SCENES)

func cast():
	var board = me.get_board()
	var index = board.make_index()
	var builder = BoardBuilder.new(board)
	var here = me.get_cell_coord()
	var creature = load(get_creature_path()).instantiate()
	var there = builder.place(creature, false, here, true, null, index)
	var devices = me.get_items(["vital-assemblage"], ["broken"])
	me.give_item(Rand.choice(devices), creature)
	
	# turn the new spawn into a servant
	creature.faction = me.faction
	
	creature.show()
	Tender.viewport.effect_at_coord("magic_sfx_01", there)
	me.use_mana(mana_cost)
