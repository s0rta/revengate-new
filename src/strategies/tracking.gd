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
	
## A metrics pump that considers crowding behind a path blocked by a 
## friend a valid move
class CrowdingMetricsPump extends RevBoard.MetricsPump:
	const crowding_slowdown = 8
	var index
	var prey
	
	func _init(board, prey_):
		super(board)
		index = board.make_index()
		prey = prey_
	
	func dist_real(here, there):
		
		var dist = board.dist(here, there)
		var actor = index.actor_at(there)
		if actor != null and actor != prey:
			dist = dist + crowding_slowdown
		return dist

	func dist_estim(here, there):
		return board.dist(here, there)
		
	func dist_tiebreak(here, there):
		return board.man_dist(here, there)
		
func act() -> bool:	
	# attack if we can, move towards foe otherwise
	var board: RevBoard = me.get_board()
	var start = me.get_cell_coord()
	var foe_coord = foe.get_cell_coord()
	var index = board.make_index()
	if board.dist(me, foe) <= me.get_max_weapon_range():
		await me.attack(foe)
		return true
	else:
		var pred = func(coord):
			if not board.is_walkable(coord):
				return false

			var other = index.actor_at(coord)
			if other == null or me.is_friend(other):
				return true
			return false
				
		var metrics = board.astar_metrics_custom(CrowdingMetricsPump.new(board, foe), start, foe_coord, 
													false, -1, pred, index)

		var path = metrics.path()
		if path != null and len(path) >= 2 and index.is_free(path[1]):
			me.move_to(path[1])
			return true
		else:
			return false

