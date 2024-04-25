# Copyright © 2024 Yannick Gingras <ygingras@ygingras.net> and contributors

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

## Utilities related to path finding
class_name Paths extends Object

## Optionally used to produce the intermediate values of a BoardMetrics
class MetricsPump:
	var board
	var metrics: DistMetrics2i
	
	func _init(board_):
		board = board_
	
	func set_metrics(metrics_:DistMetrics2i):
		metrics = metrics_
	
	func dist_real(here, there):
		assert(false, "not implemented")

	func dist_estim(here, there):
		assert(false, "not implemented")

	func dist_tiebreak(here, there):
		assert(false, "not implemented")

	func adjacents(coord, filter_pred=null) -> Array[Vector2i]:
		return board.adjacents_walkable(coord, filter_pred)

## Implement the metrics used for the movement of most actors
class StandardMetricsPump extends MetricsPump:
	func dist_real(here, there):
		return board.dist(here, there)

	func dist_estim(here, there):
		return board.dist(here, there)
		
	func dist_tiebreak(here, there):
		return board.man_dist(here, there)

## Implement metrics that favor following the edge of walls
class WallHugMetricsPump extends MetricsPump:
	var wall_counts: DistMetrics2i.Matrix2i  # number of walls that are in man_dist()=1 for a given coord
	
	func _init(board_):
		super(board_)
		wall_counts = DistMetrics2i.Matrix2i.new(board.get_used_rect().size, -1)

	func dist_real(here, there):
		# Using Manhattan dist to discourage diagonals, they are still legal but cost +1.
		# It's also more expensive to go where there are fewer walls, up to a certain point.
		return board.man_dist(here, there) + max(0, 2-get_wall_counts(there))

	func dist_estim(here, there):
		return board.man_dist(here, there)
		
	func dist_tiebreak(here, there):
		return 0

	func get_wall_counts(coord) -> int:
		## lazy compute the values when requested
		var val = wall_counts.getv(coord)
		if val == -1:
			val = 0
			for offset in Geom.CROSS_OFFSETS:
				if not board.is_walkable(coord+offset):
					val += 1
			wall_counts.setv(coord, val)
		return val

## A metrics pump that considers crowding behind a path blocked by a 
## friend a valid move
class CrowdingMetricsPump extends MetricsPump:
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

## A pump used for passage layout during Procgen rather than path finding
class CarvingPump extends MetricsPump:
	func dist_real(here, there):
		return board.man_dist(here, there)

	func dist_estim(here, there):
		return board.dist(here, there)
		
	func dist_tiebreak(here, there):
		return board.man_dist(here, there)

	func _near_other_corridors(coord):
		var other_floors = board.adjacents_walkable(coord, func(coord): return not metrics.has(coord))
		return not other_floors.is_empty()

	func adjacents(coord, filter_pred=null) -> Array[Vector2i]:
		var coords : Array[Vector2i] = board.adjacents_cross(coord)		
		coords = coords.filter(func(coord): return not (board.is_walkable(coord) or _near_other_corridors(coord)))
		if filter_pred != null:
			coords = coords.filter(filter_pred)
		return coords
