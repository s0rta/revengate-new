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
const VERBOSE := false  # are we printing lots of debug info?

var has_activated: bool
var next_move: Vector2i

func _nb_peers_at(coord, radius, board, index):
	var nb_peers = 0
	for actor in index.get_actors():
		if actor == me:
			continue
		if CombatUtils.are_peers(me, actor) and board.dist(me, coord) <= radius:
			if me.perceives(actor):
				nb_peers += 1
	return nb_peers

func refresh(turn):
	has_activated = false
	var board = me.get_board()
	var index = board.make_index()
	var here = me.get_cell_coord()
	
	var is_peer = CombatUtils.are_peers.bind(me)
	var peers = index.get_actors().filter(is_peer)
	var perc_all = peers.filter(func (actor): return me.perceives(actor))
	
	if VERBOSE:
		print("Refreshing Swarming for %s" % [me])
		print("  %d peers here" % len(peers))
		var unperc_all = peers.filter(func (actor): return not me.perceives(actor))
		var in_radius = peers.filter(func (actor): return board.dist(me, actor) <= INFLUENCE_RADIUS)
		var unperc_in_radius = in_radius.filter(func (actor): return not me.perceives(actor))
		print("  %d peers unperceived" % len(unperc_all))
		print("  %d nearby peers unperceived" % len(unperc_in_radius))

	
	var nb_peers = _nb_peers_at(here, INFLUENCE_RADIUS, board, index)	
	if nb_peers >= REQ_NB_PEERS:
		# already swarming, nothing to do	
		if VERBOSE:
			print("  Already swarming!")
		return
		
	# see if any legal move could get us closer to swarming
	var moves = []
	
	if not perc_all.is_empty():
	
		var dist_here = board.dist.bind(here)
		var cur_dist = 1.0 * Utils.sum(perc_all.map(dist_here)) / len(perc_all)
		
		for adj in board.adjacents(here, true, true, null, index):  # only returns legal moves
			dist_here = board.dist.bind(adj)
			var new_dist = 1.0 * Utils.sum(perc_all.map(dist_here)) / len(perc_all)
			if new_dist < cur_dist:
				moves.append(adj)
		
		if not moves.is_empty():
			has_activated = true
			next_move = Rand.choice(moves)
			
			if VERBOSE:
				print("  perceived peers are at: %s" % [perc_all.map(func (actor): return board.coord_str(actor.get_cell_coord()))])
				print("  Approaching the swarm: %s -> %s" % [board.coord_str(here), board.coord_str(next_move)])
		elif VERBOSE:
			print("  No way to get swarming: avg dist stays the same everywhere")

		
	elif VERBOSE:
		print("  No way to get swarming: no visible peers")


func is_valid():
	var here = me.get_cell_coord()
	return super() and has_activated

func act() -> bool:
	me.move_to(next_move)
	return true
