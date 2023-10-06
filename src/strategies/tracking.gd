# Copyright © 2022-2023 Yannick Gingras <ygingras@ygingras.net> and contributors

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

## Track an enemy at every move.
class_name Tracking extends Strategy

# how many turns to keep tracking an unavaiable target before giving up and 
# trying to pick someone else.
@export var nb_track_turns := 10

var foe
var foe_last_seen

func select_foe(actor, index:RevBoard.BoardIndex):
	## Return a foe to attack from the current location of null if there are no suitable targets.
	var max_dist = max(Actor.MAX_AWARENESS_DIST, Actor.MAX_SIGHT_DIST)
	var foes = index.actor_foes(me, max_dist)
	foes = foes.filter(me.perceives)
	if not foes.is_empty():
		foe = Rand.choice(foes)
		return foe
	else:
		return null

func refresh(turn):
	if foe != null and me.is_foe(foe):
		if me.perceives(foe): 
			foe_last_seen = turn
			return
		elif turn - foe_last_seen <= nb_track_turns:
			# still tracking
			return
	# we need a new foe!
	var index = me.get_board().make_index()
	foe = select_foe(me, index)
	foe_last_seen = turn

func is_valid():
	return super() and foe != null
		
func act() -> bool:	
	# attack if we can, move towards foe otherwise
	var board = me.get_board()
	if board.dist(me, foe) <= me.get_max_weapon_range():
		var acted = await me.attack(foe)
		return acted
	else:
		return me.move_toward_actor(foe)
	
