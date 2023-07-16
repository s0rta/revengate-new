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

class_name ElectricZap extends Spell

@export var range:= 3
@export var base_damage := 5
@export var stun_turns := 3

func _ready():
	super()
	mana_cost = 12
	tags.append("attack")
	damage_family = Consts.DamageFamily.ELECTRIC

func cast_on(victim:Actor):
	var here = me.get_cell_coord()
	var there = victim.get_cell_coord()
	Tender.viewport.effect_between_coords("zap_sfx", here, there)
	var damage = victim.normalize_damage(self, base_damage)
	victim.update_health(-damage)
	
	# stun!
	var strat = Paralized.new(victim, 1.0, stun_turns)
	victim.add_strategy(strat)

	me.use_mana(mana_cost)
