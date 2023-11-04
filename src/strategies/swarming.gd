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

## Stay close to a group of your peers
class_name Swarming extends Strategy

const INFLUENCE_RADIUS = 4
const REQ_NB_PEERS = 4  # number of nearby peers to be considered part of the swarm

var has_activated: bool
var next_move: Vector2i

func _nb_peers_at(coord, board, index):
	var nb_peers = 0
	for actor in index.get_actors():
		if actor == me:
			continue
		if CombatUtils.are_peers(me, actor) and board.dist(me, coord) <= INFLUENCE_RADIUS:
			if me.perceives(actor):
				nb_peers += 1
	return nb_peers

func refresh(turn):
	has_activated = false
	var board = me.get_board()
	var index = board.make_index()
	var here = me.get_cell_coord()
	
	var nb_peers = _nb_peers_at(here, board, index)	
	if nb_peers >= REQ_NB_PEERS:
		# already swarming, nothing to do
		
		# DEBUG
		print("Already swarming!")
		
		return false
		
	# see if any legal move could get us closer to swarming
	var moves = []
	for adj in board.adjacents(here):  # only returns legal moves by default
		# FIXME: how many peers can we reach with those moves?
		if _nb_peers_at(adj, board, index) > nb_peers:
			moves.append(adj)
	
	if not moves.is_empty():
		has_activated = true
		next_move = Rand.choice(moves)
		
		# DEBUG
		print("Approaching the swarm: %s -> %s" % [board.coord_str(here), board.coord_str(next_move)])

		
	else:
		# DEBUG
		print("No way to get swarming")


func is_valid():
	return super() and has_activated

func act() -> bool:
	me.move_to(next_move)
	return true
