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

static func rect_perim(rect: Rect2i, region=null) -> Array[Vector2i]:
	## Return all the coordinates making the inner perimeter of a rectangle.
	## The coordinates are returned clockfise starting at rect.position.
	## region: one of Consts.REG_*, if supplied, only coords from this side are included.
	##         Which region a corner falls into is arbitrary. Each corner is only part 
	##         of a single region.
	
	if region != null:
		assert(region != Consts.REG_CENTER, 
				"REG_CENTER does not intersect with the perimeter of the rectable.")
	
	var coords:Array[Vector2i] = []
	if region == null or region == Consts.REG_NORTH:
		for i in range(rect.size.x):
			coords.append(rect.position + V.i(i, 0))
	if region == null or region == Consts.REG_EAST:
		for j in range(1, rect.size.y):
			coords.append(rect.position + V.i(rect.size.x-1, j))
	if region == null or region == Consts.REG_SOUTH:
		for i in range(rect.size.x-2, 0, -1):
			coords.append(rect.position + V.i(i, rect.size.y-1))
	if region == null or region == Consts.REG_WEST:
		for j in range(rect.size.y-1, 0, -1):
			coords.append(rect.position + V.i(0, j))
	return coords

static func rect_area(rect: Rect2i) -> int:
	return rect.get_area()

static func inner_rect(rect:Rect2i, margin=0):
	## Return a Rect2i that is one tile inside `rect`
	## margin: if >0, that many tiles separate the outer rect perimiter tiles from the inner rect.
	var delta = Vector2i.ONE * (1 + margin)
	assert(rect.size.x > delta.x*2 and rect.size.y > delta.y*2, 
			"%s is too small to contain an inner rect" % rect)
	return Rect2i(rect.position+delta, rect.size-delta*2)

static func coord_region(coord:Vector2i, rect:Rect2i):
	## Return a 0..1 vector telling us where the coord is inside rect.
	## The return value represent one of the 4 cardinal points or the center [0:0]
	var offset = coord - rect.position
	var ratio = Vector2(abs(offset)) / Vector2(rect.size - Vector2i.ONE)  # transposed in 0..1
	if CENTRAL_REGION_MARGIN < ratio.x and ratio.x < 1.0 - CENTRAL_REGION_MARGIN:
		if 0.3 < ratio.y and ratio.y < 1.0 - CENTRAL_REGION_MARGIN:
			return Consts.REG_CENTER
	
	# diag1 is NW-SW, x-y=0, sign test is x-y
	# diag2 is SW-NE, -x-y=1, sign test is -x-y+1
	# The sign is positive if we are above the diag. The test is well explained here:
	# https://math.stackexchange.com/questions/757591/how-to-determine-the-side-on-which-a-point-lies
	var s1 = sign(ratio.x - ratio.y)
	var s2 = sign(-ratio.x - ratio.y + 1.0)
	if s1 >= 0 and s2 >= 0: 
		return Consts.REG_NORTH
	elif s1 <= 0 and s2 <= 0: 
		return Consts.REG_SOUTH
	elif s1 < 0 and s2 > 0:
		return Consts.REG_WEST
	elif s1 > 0 and s2 < 0:
		return Consts.REG_EAST
	else:
		assert(false, "failed to find the region for %s" % RevBoard.coord_str(coord))

static func region_has_coord(rect, region, coord):
	## Return whether `coord` is inside a given region.
	var offset = coord - rect.position
	var ratio = Vector2(abs(offset)) / Vector2(rect.size - Vector2i.ONE)  # transposed in 0..1
	if CENTRAL_REGION_MARGIN < ratio.x and ratio.x < 1.0 - CENTRAL_REGION_MARGIN:
		if 0.3 < ratio.y and ratio.y < 1.0 - CENTRAL_REGION_MARGIN:
			return region == Consts.REG_CENTER
	# see the comments in coord_region() to know how the signs work
	var s1 = sign(ratio.x - ratio.y)
	var s2 = sign(-ratio.x - ratio.y + 1.0)
	
	if region == Consts.REG_NORTH:
		return s1 >= 0 and s2 >= 0
	elif region == Consts.REG_SOUTH:
		return s1 <= 0 and s2 <= 0
	elif region == Consts.REG_WEST:
		return s1 < 0 and s2 > 0
	elif region == Consts.REG_EAST:
		return s1 > 0 and s2 < 0
	elif region == Consts.REG_CENTER:
		return false
	else:
		assert(false, "unknown region %s" % region)

static func region_bounding_rect(rect:Rect2i, region:Vector2i):
	## Return return a rect that fully encloses `region`. This might also include some coordinates
	## outside of the region since most regions are not rectangular.
	if region == Consts.REG_CENTER:
		var in_pos = Vector2i((CENTRAL_REGION_MARGIN * rect.size).round())
		var in_size = Vector2i((1.0 - 2*CENTRAL_REGION_MARGIN) * rect.size)
		return Rect2i(rect.position + in_pos, in_size)
	elif region == Consts.REG_NORTH:
		var in_size = Vector2i(rect.size.x, roundi(CENTRAL_REGION_MARGIN*rect.size.y))
		return Rect2i(rect.position, in_size)
	elif region == Consts.REG_SOUTH:
		var in_size = Vector2i(rect.size.x, roundi(CENTRAL_REGION_MARGIN*rect.size.y))
		var in_pos = Vector2i(0, (1.0-CENTRAL_REGION_MARGIN)*rect.size.y)
		return Rect2i(rect.position + in_pos, in_size)
	elif region == Consts.REG_WEST:
		var in_size = Vector2i(roundi(CENTRAL_REGION_MARGIN*rect.size.x), rect.size.y)
		return Rect2i(rect.position, in_size)
	elif region == Consts.REG_EAST:
		var in_size = Vector2i(roundi(CENTRAL_REGION_MARGIN*rect.size.x), rect.size.y)
		var in_pos = Vector2i((1.0-CENTRAL_REGION_MARGIN)*rect.size.x, 0)
		return Rect2i(rect.position + in_pos, in_size)
	else:
		assert(false, "Invalid region: %s" % region)

static func region_outside_rect(rect:Rect2i, region:Vector2i):
	## Return the complement of a region bounding rect. The rect won't contain any coords from 
	## the region, but it might not contain all the coords that are not in the region sice some 
	## regions are not rectangular.
	## REG_CENTER does not have an outside-rect

	var reg_rect = region_bounding_rect(rect, region)

	if region == Consts.REG_NORTH:
		var size = Vector2i(rect.size.x, rect.size.y - reg_rect.size.y)
		return Rect2i(Vector2i(rect.position.x, reg_rect.end.y), size)
	elif region == Consts.REG_SOUTH:
		var size = Vector2i(rect.size.x, rect.size.y - reg_rect.size.y)
		return Rect2i(rect.position, size)
	elif region == Consts.REG_WEST:
		var size = Vector2i(rect.size.x - reg_rect.size.x, rect.size.y)
		return Rect2i(Vector2i(reg_rect.end.x, rect.position.y), size)
	elif region == Consts.REG_EAST:
		var size = Vector2i(rect.size.x - reg_rect.size.x, rect.size.y)
		return Rect2i(rect.position, size)
	else:
		assert(false, "Invalid region: %s" % region)

static func interpolate_path(path:Array[Vector2i]) -> Array[Vector2i]:
	## Return an array of coords that connect all the elements of `path`. 
	## The Manhattan dist between successive coords will always be 1 (no diagonals). 
	## Elements of path are included.
	var coords:Array[Vector2i] = [path[0]]
	var dir
	var diff
	for i in range(1, len(path)):
		var prev = coords[-1]
		if prev.x != path[i].x:
			diff = path[i].x - prev.x
			dir = sign(diff)
			for k in abs(diff) - 1:
				coords.append(coords[-1] + Vector2i.RIGHT * dir)
			if prev.y != path[i].y:
				coords.append(coords[-1] + Vector2i.RIGHT * dir)
		if prev.y != path[i].y:
			diff = path[i].y - prev.y
			dir = sign(diff)
			for k in abs(diff) - 1:
				coords.append(coords[-1] + Vector2i.DOWN * dir)
		coords.append(path[i])
	return coords

static func move_path(path:Array[Vector2i], offset:Vector2i) -> Array[Vector2i]:
	## Return a new path that corresponds to `path` translated by `offset`
	var new_path:Array[Vector2i] = []
	for coord in path:
		new_path.append(coord + offset)
	return new_path
