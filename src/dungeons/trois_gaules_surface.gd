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


class_name TroisGaulesSurface extends LyonSurface

@export var start_world_loc: Vector3i
@export var dest_world_loc: Vector3i

func dungeon_for_loc(world_loc:Vector3i):
	## Return the name of the dungeon where `world_loc` belongs or null is it's part of the current dungeon
	return null

func _neighbors_for_level(depth:int, world_loc:Vector3i, prev=null):
	var locs = []
	if prev != null:
		locs.append(prev)

	# strickly travel East-West until we align, then North-South, then down, but never up
	if dest_world_loc != Consts.LOC_INVALID and world_loc != dest_world_loc:
		var delta:Vector3i = dest_world_loc - world_loc
		var delta_s := delta.sign()
		if delta.x:
			locs.append(world_loc + Vector3i(delta_s.x, 0, 0))
		elif delta.y:
			locs.append(world_loc + Vector3i(0, delta_s.y, 0))
		elif delta.z < 0:
			locs.append(world_loc + Vector3i(0, 0, delta_s.z))
		else:
			assert(false, "Can't go to %s from %s" % [dest_world_loc, world_loc].map(RevBoard.world_loc_str))

	var mk_rec = _conn_rec_for_loc.bind(world_loc, prev, depth)
	return locs.map(mk_rec)
