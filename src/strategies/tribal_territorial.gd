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

## Defend your personal space if your are near actors who look like you and 
## thereby make your feel territorial
class_name TribalTerritorial extends Strategy

const INFLUENCE_RADIUS = 5

var has_activated := false
var intruder: Actor

func _is_like_me(other):
	return other != me and other.char == me.char and other.faction == me.faction

func refresh(turn):
	has_activated = false
	var board = me.get_board()
	var index = board.make_index()
	
	var nb_supporters = 0
	for actor in index.get_actors():
		if actor == me:
			continue
		if _is_like_me(actor) and board.dist(me, actor) <= INFLUENCE_RADIUS:
			nb_supporters += 1
	
	var pers_space_radius = (nb_supporters - 1) * 3
	if pers_space_radius > 0:
		var intruder_dist = INF
		for actor in index.get_actors():
			var actor_dist = board.dist(me, actor)
			if actor.faction != me.faction and actor_dist <= pers_space_radius:
				if actor_dist < intruder_dist:
					intruder = actor
					has_activated = true

func is_valid():
	return super() and has_activated

func act() -> bool:
	var board = me.get_board() as RevBoard
		
	if board == null:
		# we're are not in a complete scene
		return false

	# attack if we can, move towards the intruder otherwise
	if board.dist(me, intruder) == 1:
		var acted = await me.attack(intruder)
		return acted
	else:
		return me.move_toward_actor(intruder)
