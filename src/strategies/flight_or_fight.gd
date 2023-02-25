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

## Run as far as possible from your attacker, or fight back if you can't escape!
class_name FlightOrFight extends Strategy
@export_range(0.0, 1.0) var probability

var tested_for_turn = null
var has_activated = null
var attacker = null

func is_valid():
	if not super():
		return false
	var fact = me.mem.recall("was_attacked")
	if fact == null:
		attacker = null
		return false
		
	if fact.turn != tested_for_turn:
		tested_for_turn = fact.turn
		has_activated = Rand.rstest(probability)
		# TODO: give up if foe is too far or long enough has passed since the attack
		attacker = fact.attacker
	return has_activated and attacker != null and attacker.is_alive()

func act() -> bool:
	print("Flight or Fighting")
	var my_coord = me.get_cell_coord()
	var bully_coord = attacker.get_cell_coord()
	var board = me.get_board() as RevBoard
	var index = board.make_index()
	var cells = board.adjacents(my_coord, true, true, null, index)
	
	var cur_dist = board.dist(my_coord, bully_coord)
	var elems = []
	for cell in cells:
		var dist = board.dist(cell, bully_coord)
		if dist >= cur_dist:
			elems.append([dist, cell])
	elems.sort()
	if not elems.is_empty():
		var dest = elems[-1][-1]
		return me.move_to(dest)
	elif cur_dist == 1:  # TODO: use our attack range instead of 1
		# Bully is within range
		var acted = await me.attack(attacker)
		return acted
	else:
		# no good spot to move, bully is too far, just panic and attack anyone within reach
		assert(false, "not implemented")
		return false
