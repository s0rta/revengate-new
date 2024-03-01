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
class_name OffensiveCasting extends Strategy

@export_range(0.0, 1.0) var probability = 0.1

var has_activated = null
var spells := []  # all the spells we know
var spell = null  # selected spell, random if more than one available.
var targets := []  # all possible targets
var target = null

func refresh(turn):
	has_activated = Rand.rstest(probability)
	spells = me.get_spells(["attack"])
	spells.shuffle()
	var ranges = [0]
	for spell in spells:
		ranges.append(spell.get("range", 0))
	var max_range = ranges.max()
	var here = me.get_cell_coord()
	var index = me.get_board().make_index()
	targets = index.get_actors_in_sight(here, max_range)
	targets = targets.filter(me.is_foe)
	targets.shuffle()

func is_valid():
	if not super():
		return false
	if not has_activated:
		return false
	if spells.is_empty() or targets.is_empty():
		return false
	
	var board = me.get_board()
	for sp in spells:
		for actor in targets:
			if not sp.has_reqs():
				continue
			if sp.range == null or board.dist(me, actor) >= sp.range:
				spell = sp
				target = actor
				return true			
	spell = null
	target = null
	return false

func act() -> bool:
	spell.cast_on(target)
	return true
