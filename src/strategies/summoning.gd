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

## Opportunistically fight back after being attacked.
class_name Summoning extends Strategy

@export var mana_cost := 10
@export_range(0.0, 1.0) var probability = 0.5

var has_activated = null
var threat_radius = 5

func refresh(turn):
	has_activated = Rand.rstest(probability)

func is_valid():
	if not super():
		return false
	if not has_activated:
		return false
	var index = me.get_board().make_index()	
	if index.actor_foes(me, threat_radius).is_empty():
		return false
	return me.mana >= mana_cost

func act() -> bool:
	var board = me.get_board()
	var index = board.make_index()
	var builder = BoardBuilder.new(board)
	var here = me.get_cell_coord()
	var creature = load("res://src/monsters/phantruch-higher.tscn").instantiate()
	var there = builder.place(creature, false, here, true, null, index)
	creature.show()
	Tender.viewport.effect_at_coord("magic_vfx_01", there)
	me.mana -= mana_cost
	return true
