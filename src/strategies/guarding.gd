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

## Guard a "client": stay close and attack their foes.
class_name Guarding extends Strategy

# TODO: @tool rule to check if client_tags is sane
@export var client_tags:Array[String]

var client  # Actor
var foe  # Actor
var waypoint  # Vector2i
var path
var index
var guard_radius:int

func _ready():
	super()
	Utils.assert_all_tags(client_tags)

func refresh(turn):	
	path = null
	var ranges = me.get_perception_ranges()
	guard_radius = ranges.aware
	var here = me.get_cell_coord()
	var board = me.get_board()
	index = board.make_index()
	if client != null and not client.is_alive():
		# our previous client didn't make it...
		client = null
		waypoint = null
	
	if client == null:
		# try to pick a new client
		var actors = board.get_actors(client_tags)
		actors.filter(func(actor): return actor.is_alive())
		if actors.is_empty():
			return
		client = Rand.choice(actors)

	if _can_retaliate():
		# will fight back
		return 
	
	# can we get closer to the client?
	var client_coord = client.get_cell_coord()	
	if waypoint != null and not _valid_waypoint(waypoint, client_coord):
		waypoint = null
		
	if waypoint == null:
		var index = board.make_index()
		var pred = _mk_walkable_pred(client_coord, index)
		var metrics = board.dist_metrics(here, null, false, null, pred, index)

		if metrics.getv(client_coord) == null:
			# client is currently unreachable
			return
		var coords = metrics.all_coords()
		coords = coords.filter(func (coord): return board.dist(client_coord, coord) <= guard_radius)
		assert(not coords.is_empty(), 
				"What the hell, client is reachable but no free coords nearby??")
		waypoint = Rand.choice(coords)
		path = metrics.path(waypoint)

func _mk_walkable_pred(client_coord, index):
	## Return a coord filter based on our perception.
	# We know that the client cell is not walkable, but we include it in the dist metrics 
	# to find out if the client is reachable. Using `dest=client_coord` in 
	# `board.dist_metrics()` would achieve the same result, but it would cause an early exit 
	# and return sparse metrics. In this case, we want a comprehensive survey of the board.
	var pred = func(coord):
		return coord == client_coord or me.perceives_free(coord, index)
	return pred
	
func _valid_waypoint(waypoint, client_coord):
	var board = index.board
	if board.dist(client_coord, waypoint) > guard_radius:
		return false
	if not me.perceives_free(waypoint, index):
		return false
	path = board.path_perceived(me.get_cell_coord(), waypoint, me, true, null, index)
	return path != null

func _can_retaliate():
	var fact = client.mem.recall("was_attacked")
	if fact and fact.attacker and fact.attacker.is_alive():
		var range = me.get_max_weapon_range()
		if index.board.dist(me, fact.attacker) <= range:
			foe = fact.attacker
			return true
		var here = me.get_cell_coord()
		var there = fact.attacker.get_cell_coord()
		# FIXME: must look for a free destination since we know foe is there
		path = index.board.path_perceived(here, there, me, false, null, index)
		if path != null:
			foe = fact.attacker
			return true
	foe = null
	return false

func is_valid():
	if not super():
		return false
	if client == null:
		return false
	if foe != null or waypoint != null:
		return true
	else:
		return false
	
func act() -> bool:	
	var msg = "%s is guarging %s" % [me.get_short_desc(), client.get_short_desc()]
	print(msg)
	me.add_message(msg)

	# Retaliate
	if foe != null:
		var range = me.get_max_weapon_range()
		if index.board.dist(me, foe) <= range:
			me.attack(foe)
			return true
		
	# Get closer
	var there = _path_next(path)
	print("Client is at %s, going to %s" % [RevBoard.coord_str(client.get_cell_coord()), RevBoard.coord_str(there)])

	me.move_to(there)
	return true
