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

## Defend your personal space if your are with actors who look like your and make 
## your feel territorial
class_name TribalTerritorial extends Strategy

const INFLUENCE_RADIUS = 5

var has_activated := false
var intruder: Actor

func refresh(turn):
	has_activated = false
	var board = me.get_board()
	var index = board.make_index()
	var my_coord = me.get_cell_coord()
	
	var nb_supporters = 0
	for actor in index.get_actors():
		if actor == me:
			continue
		var has_influence = board.dist(my_coord, actor.get_cell_coord()) <= INFLUENCE_RADIUS
		if actor.char == me.char and has_influence:
			nb_supporters += 1
	
	var pers_space_radius = (nb_supporters - 1) * 3
	if pers_space_radius > 0:
		var intruder_dist = INF
		for actor in index.get_actors():
			var actor_dist = board.dist(my_coord, actor.get_cell_coord())
			if actor.faction != me.faction and actor_dist <= pers_space_radius:
				if actor_dist < intruder_dist:
					intruder = actor
					has_activated = true

func is_valid():
	print("Tribal.is_valid(): has_activated=%s" % has_activated)
	return super() and has_activated

func act() -> bool:
	var board = me.get_board() as RevBoard
		
	if board == null:
		# we're are not in a complete scene
		return false

	# attack if we can, move towards the intruder otherwise
	var my_coord = me.get_cell_coord()
	var foe_coord = intruder.get_cell_coord()
	if board.dist(my_coord, foe_coord) == 1:
		var acted = await me.attack(intruder)
		return acted
	else:
		return me.move_toward_actor(intruder)
