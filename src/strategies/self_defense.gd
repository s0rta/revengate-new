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
class_name SelfDefense extends Strategy

var attacker = null

func is_valid():
	if not super():
		return false
	var fact = me.mem.recall("was_attacked")
	if fact == null:
		attacker = null
		return false
	# TODO: give up if foe is too far or long enough has passed since the attack
	attacker = fact.attacker
	return attacker.is_alive()

func act():
	var board = me.get_board()
	var my_coord = me.get_cell_coord()
	var foe_coord = attacker.get_cell_coord()
	if board.dist(my_coord, foe_coord) == 1:
		var anim = await me.attack(attacker)
		return anim
	else:
		return me.move_toward_actor(attacker)
