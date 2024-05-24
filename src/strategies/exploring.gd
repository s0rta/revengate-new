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

## Go from one far away waypoint to the other
class_name Exploring extends Strategy
@export var hug_walls := false

const MAX_TRAVEL_ATTEMPTS = 5
const MAX_PATH_TTL = 5  # number of times we can recycle a path from previous turns
# If we have to explore more than that, it slows down the game without significantly
# improving how smart the monsters feel.
const MAX_WAYPOINT_STEPS := 600

var waypoint := Consts.COORD_INVALID
var nb_travel_attempts := 0
var path = null  # Array[Vector2i], but it can be null
var path_ttl := -1
var index = null

func refresh(turn):
	path_ttl -= 1
	index = null

func find_suitable_waypoint() -> Vector2i:
	## Return a random reachable location that is biased towards being far
	var board: RevBoard = me.get_board()
	var size = board.get_used_rect().size
	var long_side = max(size.x, size.y)
	
	# we randomize the max dist to avoid having all the exploring 
	# actors re-pick a waypoint when they reach destination at the same time
	var max_dist = min(15, long_side/2)
	max_dist = randi_range(0.65 * max_dist, max_dist)
	
	var here = me.get_cell_coord()
	var metrics = board.dist_metrics(here, Consts.COORD_INVALID, false, max_dist, MAX_WAYPOINT_STEPS, null, index)
	if metrics.furthest_coord == here:
		return Consts.COORD_INVALID	
	return Rand.weighted_choice(metrics.all_coords(), metrics.all_dists())
	
func _get_path(here:Vector2i, there:Vector2i):
	# TODO: use perceived_path()
	var board: RevBoard = me.get_board()
	if hug_walls:
		var pump = Paths.WallHugMetricsPump.new(board)
		var metrics = board.astar_metrics_custom(pump, here, there, true, -1, null, index)
		return metrics.path()
	else:
		return board.path(here, there, true, -1, index)

func advance_path():
	var last_valid_idx = -1
	var here = me.get_cell_coord()
	for i in min(path_ttl, len(path)):
		if path[i] == here or Geom.cheby_dist(here, path[i]) == 1:
			last_valid_idx = i
	if last_valid_idx >= 0:
		path = path.slice(last_valid_idx)
	else:
		path = []
		
func is_path_clear() -> bool:
	## Return whether the next few steps of the path are free and walkable
	for i in min(3, len(path), path_ttl):
		if not index.is_free(path[i]):
			return false
	return true

func act() -> bool:
	index = me.get_board().make_index()
	var here = me.get_cell_coord()
	if here == waypoint or nb_travel_attempts >= MAX_TRAVEL_ATTEMPTS:
		waypoint = Consts.COORD_INVALID
		
	if waypoint == Consts.COORD_INVALID:
		nb_travel_attempts = 0
		waypoint = find_suitable_waypoint()
		if waypoint == Consts.COORD_INVALID:
			# We're stuck in a tight spot. We'll try again next turn.
			# TODO: this could be detected in is_valid(), but usually Exploring is a low-pri
			#   strategy so that probably won't help much.
			return false
	
	var path_is_bad = false
	if not path or path_ttl <= 0:
		path_is_bad = true
	else:
		advance_path()
		if not path or not is_path_clear():
			path_is_bad = true
			
	if path_is_bad:
		path = _get_path(here, waypoint)
		path_ttl = MAX_PATH_TTL

	if path and len(path) >= 2:
		var step = _path_next(path)
		path = path.slice(path.find(step))
		highlight_path(path)
		me.move_to(step)
		return true
	else:
		nb_travel_attempts += 1
		return false
