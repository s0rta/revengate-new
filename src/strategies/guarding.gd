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
var waypoint  # Vector2i
var waypoint_path
var index
var guard_radius:int

func _ready():
	super()
	Utils.assert_all_tags(client_tags)

func refresh(turn):	
	waypoint_path = null
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
		waypoint_path = metrics.path(waypoint)

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
	waypoint_path = board.path_perceived(me.get_cell_coord(), waypoint, me, null, index)
	return waypoint_path != null

func is_valid():
	return super() and client != null and waypoint != null
	
func act() -> bool:	
	var msg = "%s is guarging %s" % [me.get_short_desc(), client.get_short_desc()]
	print(msg)
	me.add_message(msg)
	print("Client is at %s, going to %s" % [RevBoard.coord_str(client.get_cell_coord()), RevBoard.coord_str(waypoint)])

	me.move_to(_path_next(waypoint_path))
	return true
