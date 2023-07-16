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
class_name DefensiveCasting extends Strategy

const HEALING_THRESHOLD = 5
@export_range(0.0, 1.0) var probability = 0.1

var has_activated = null
var spell = null  # selected spell, random if more than one available.

func refresh(turn):
	has_activated = Rand.rstest(probability)

func is_valid():
	if not super():
		return false
	if not has_activated:
		return false
	if me.health >= me.health_full - HEALING_THRESHOLD:
		return false
	var spells = me.get_spells(["healing"])
	spells.shuffle()
	for sp in spells:
		if sp.has_reqs():
			spell = sp
			return true
	spell = null
	return false

func act() -> bool:
	spell.cast()
	return true
