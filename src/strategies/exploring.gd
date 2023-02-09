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

extends Strategy

const MAX_TRAVEL_ATTEMPTS = 3


var waypoint = null   # Vector2i
var nb_travel_attempts = 0

func find_suitable_waypoint():
	var board: RevBoard = me.get_board()
	var index = board.make_index()
	var metrics = board.dist_metrics(me.get_cell_coord())
	return Rand.weighted_choice(metrics.all_coords(), metrics.all_dists())
	
# TODO:
#  - stick close to the walls if possible
	
func act():
	var my_coord = me.get_cell_coord()
	if my_coord == waypoint or nb_travel_attempts >= MAX_TRAVEL_ATTEMPTS:
		waypoint = null
	
	if waypoint == null:
		nb_travel_attempts = 0
		waypoint = find_suitable_waypoint()
		if waypoint == null:
			return
			
	var board: RevBoard = me.get_board()
	var path = board.path(my_coord, waypoint)
	if path and len(path) >= 2:
		me.move_to(path[1])
	else:
		nb_travel_attempts += 1
			
