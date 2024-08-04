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
	char = "🗲"
	caption = "zap"
	tags.append("attack")
	damage_family = Consts.DamageFamily.ELECTRIC

func cast_on(victim:Actor):
	var there = victim.get_cell_coord()
	Tender.viewport.effect_at_coord("zap_sfx", there)
	var damage = victim.normalize_damage(self, base_damage)
	victim.update_health(-damage)
	
	# stun!
	var strat = Paralized.new(victim, 1.0, stun_turns)
	## TODO: right now this adds a stratagy, but no affect, so we cannot emit
	## A message that someone has been stunned.
	victim.add_strategy(strat)

	victim.was_attacked.emit(me)

	me.use_mana(mana_cost)

func cast_at(coord:Vector2i):
	var here = me.get_cell_coord()
	Tender.viewport.effect_at_coord("zap_sfx", coord)
	me.use_mana(mana_cost)
