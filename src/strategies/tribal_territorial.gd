# Copyright © 2023–2024 Yannick Gingras <ygingras@ygingras.net> and contributors

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
const RECALL_TURNS = 5  ## how many turns you recall someone invading your personal space
@export_range(2, 10) var pers_space_mult := 3  ## how fast your personnal space grows with each supporter

var intruder: Actor
var intruder_last_seen := -1

func refresh(turn):
	# if no intruder, try to find one
	# if intruder, decay how much we hate them by how long they've been out of pers_space
	var board = me.get_board()
	var index:RevBoard.BoardIndex = board.make_index()
	
	if intruder != null:
		if me.perceives(intruder, index):
			intruder_last_seen = turn
		elif turn - intruder_last_seen > RECALL_TURNS:
			intruder = null
			
	var nb_supporters = 0
	for actor in index.get_actors():
		if actor == me:
			continue
		if CombatUtils.are_peers(me, actor) and board.dist(me, actor) <= INFLUENCE_RADIUS:
			if me.perceives(actor, index):
				nb_supporters += 1
	
	if intruder == null:
		# your personal space increases the more supporters you have
		var pers_space_radius = (nb_supporters - 1) * pers_space_mult
		if pers_space_radius > 0:
			var others = index.get_actors_around_me(me, pers_space_radius)
			others.shuffle()
			for actor in others:
				if actor.faction != me.faction and me.perceives(actor):
					intruder = actor
					intruder_last_seen = turn
					return


func is_valid():
	if not super():
		return false		
	return intruder != null
		

func act() -> bool:
	var board = me.get_board() as RevBoard
		
	if board == null:
		# we're are not in a complete scene
		return false

	# attack if we can, move towards the intruder otherwise
	if board.dist(me, intruder) == 1:
		await me.attack(intruder)
		return true
	else:
		return me.move_toward_actor(intruder)
