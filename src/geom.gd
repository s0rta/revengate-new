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

## Utilities related to geometry
class_name Geom extends Node

const CENTRAL_REGION_MARGIN := 0.25  # ration of coords that are on each side of the central region	

static func rect_perim(rect: Rect2i) -> Array:
	## Return all the coordinates making the inner perimeter of a rectangle.
	## The coordinates are returned clockfise starting at rect.position.
	var coords = []
	for i in range(rect.size.x):
		coords.append(rect.position + V.i(i, 0))
	for j in range(1, rect.size.y):
		coords.append(rect.position + V.i(rect.size.x-1, j))
	for i in range(rect.size.x-2, 0, -1):
		coords.append(rect.position + V.i(i, rect.size.y-1))
	for j in range(rect.size.y-1, 0, -1):
		coords.append(rect.position + V.i(0, j))
	return coords

static func coord_region(coord:Vector2i, rect:Rect2i):
	## Return a 0..1 vector telling us where the coord is inside rect.
	## The return value represent one of the 4 cardinal points or the center [0:0]
	var offset = coord - rect.position
	var ratio = Vector2(abs(offset)) / Vector2(rect.size - Vector2i.ONE)  # transposed in 0..1
	if CENTRAL_REGION_MARGIN < ratio.x and ratio.x < 1.0 - CENTRAL_REGION_MARGIN:
		if 0.3 < ratio.y and ratio.y < 1.0 - CENTRAL_REGION_MARGIN:
			return Vector2i.ZERO
	
	# diag1 is NW-SW, x-y=0, sign test is x-y
	# diag2 is SW-NE, -x-y=1, sign test is -x-y+1
	# The sign is positive if we are above the diag. The test is well explained here:
	# https://math.stackexchange.com/questions/757591/how-to-determine-the-side-on-which-a-point-lies
	var s1 = sign(ratio.x - ratio.y)
	var s2 = sign(-ratio.x - ratio.y + 1.0)
	if s1 >= 0 and s2 >= 0: 
		return V.i(0, -1)
	elif s1 <= 0 and s2 <= 0: 
		return V.i(0, 1)
	elif s1 < 0 and s2 > 0:
		return V.i(-1, 0)
	elif s1 > 0 and s2 < 0:
		return V.i(1, 0)
	else:
		assert(false, "failed to find the region for %s" % RevBoard.coord_str(coord))

static func region_has_coord(rect, region, coord):
	## Return whether `coord` is inside a given region.
	var offset = coord - rect.position
	var ratio = Vector2(abs(offset)) / Vector2(rect.size - Vector2i.ONE)  # transposed in 0..1
	if CENTRAL_REGION_MARGIN < ratio.x and ratio.x < 1.0 - CENTRAL_REGION_MARGIN:
		if 0.3 < ratio.y and ratio.y < 1.0 - CENTRAL_REGION_MARGIN:
			return region == Vector2i.ZERO
	# see the comments in coord_region() to know how the signs work
	var s1 = sign(ratio.x - ratio.y)
	var s2 = sign(-ratio.x - ratio.y + 1.0)
	
	if region == V.i(0, -1):
		return s1 >= 0 and s2 >= 0
	elif region == V.i(0, 1):
		return s1 <= 0 and s2 <= 0
	elif region == V.i(-1, 0):
		return s1 < 0 and s2 > 0
	elif region == V.i(1, 0):
		return s1 > 0 and s2 < 0
	elif region == Vector2i.ZERO:
		return false
	else:
		assert(false, "unknown region %s" % region)

static func region_bounding_rect(rect:Rect2i, region:Vector2i):
	## Return return a rect that fully encloses `region`. This might also include some coordinates
	## outside of the region since most regions are not rectangular.
	if region == Vector2i.ZERO:
		var in_pos = Vector2i((CENTRAL_REGION_MARGIN * rect.size).round())
		var in_size = Vector2i((1.0 - 2*CENTRAL_REGION_MARGIN) * rect.size)
		return Rect2i(rect.position + in_pos, in_size)
	elif region == Vector2i(0, -1):
		var in_size = Vector2i(rect.size.x, roundi(CENTRAL_REGION_MARGIN*rect.size.y))
		return Rect2i(rect.position, in_size)
	elif region == V.i(0, 1):
		var in_size = Vector2i(rect.size.x, roundi(CENTRAL_REGION_MARGIN*rect.size.y))
		var in_pos = Vector2i(0, (1.0-CENTRAL_REGION_MARGIN)*rect.size.y)
		return Rect2i(rect.position + in_pos, in_size)
	elif region == V.i(-1, 0):
		var in_size = Vector2i(roundi(CENTRAL_REGION_MARGIN*rect.size.x), rect.size.y)
		return Rect2i(rect.position, in_size)
	elif region == V.i(1, 0):
		var in_size = Vector2i(roundi(CENTRAL_REGION_MARGIN*rect.size.x), rect.size.y)
		var in_pos = Vector2i((1.0-CENTRAL_REGION_MARGIN)*rect.size.x, 0)
		return Rect2i(rect.position + in_pos, in_size)
	else:
		assert(false, "Invalid region: %s" % region)

