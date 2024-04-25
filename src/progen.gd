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

## Utilities related to Procedural Generation
class_name Procgen extends Object

static func connectable_sides(rect1:Rect2i, rect2:Rect2i):
	## Return a list of pairs (reg1, reg2) of sides that could be connection points for 
	## corridors between the two given rects.
	## The board geometry is not tested, this is only a guess based on the relative 
	## positions of the two rects.
	if rect1.encloses(rect2) or rect2.encloses(rect1):
		return []
	var pairs = []
	var delta:Vector2i
	var br1 = rect1.end - Vector2i.ONE
	var br2 = rect2.end - Vector2i.ONE
	if br1.y < rect2.position.y - 1:
		pairs.append([Consts.REG_SOUTH, Consts.REG_NORTH])
	if rect1.position.y > br2.y + 1:
		pairs.append([Consts.REG_NORTH, Consts.REG_SOUTH])

	if br1.x < rect2.position.x - 1:
		pairs.append([Consts.REG_EAST, Consts.REG_WEST])
	if rect1.position.x > br2.x + 1:
		pairs.append([Consts.REG_WEST, Consts.REG_EAST])
		
	delta = rect1.position - rect2.position
	if delta.x >= 2 and delta.y <= -1:
		pairs.append([Consts.REG_WEST, Consts.REG_NORTH])
	if delta.x <= -2 and delta.y >= 1:
		pairs.append([Consts.REG_NORTH, Consts.REG_WEST])
		
	var tr1 = Vector2i(br1.x, rect1.position.y)
	var tr2 = Vector2i(br2.x, rect2.position.y)
	delta = tr1 - tr2
	if delta.x <= -2 and delta.y <= -1:
		pairs.append([Consts.REG_EAST, Consts.REG_NORTH])
	if delta.x >= 2 and delta.y >= 1:
		pairs.append([Consts.REG_NORTH, Consts.REG_EAST])

	var bl1 = Vector2i(rect1.position.x, br1.y)
	var bl2 = Vector2i(rect2.position.x, br2.y)
	delta = bl1 - bl2
	if delta.x >= 2 and delta.y >= 1:
		pairs.append([Consts.REG_WEST, Consts.REG_SOUTH])
	if delta.x <= -2 and delta.y <= -1:
		pairs.append([Consts.REG_SOUTH, Consts.REG_WEST])

	delta = br1 - br2
	if delta.x <= -2 and delta.y >= 1:
		pairs.append([Consts.REG_EAST, Consts.REG_SOUTH])
	if delta.x >= 2 and delta.y <= -1:
		pairs.append([Consts.REG_SOUTH, Consts.REG_EAST])

	return pairs
	
static func connectable_near_coords(near_rect:Rect2i, near_side:Vector2i, 
									far_rect:Rect2i, far_side:Vector2i, 
									shuffle=true):
	## Return an arrays of coords representing which wall cells are elegible to be the start 
	## of a passage between `near_rect` and `far_rect`. The path between those is not tested 
	## and there can be obstructions preventing the carving of an actuall passage. 
	## Return an empty array if there are no valid coords.
	var pred = func(coord): return not Geom.is_corner(coord, near_rect)
	if far_side == Consts.REG_NORTH:
		pred = func(coord): return pred.call(coord) && coord.y < far_rect.position.y
	elif far_side == Consts.REG_SOUTH:
		pred = func(coord): return pred.call(coord) && coord.y > far_rect.end.y - 1
	elif far_side == Consts.REG_WEST:
		pred = func(coord): return pred.call(coord) && coord.x < far_rect.position.x
	elif far_side == Consts.REG_EAST:
		pred = func(coord): return pred.call(coord) && coord.x > far_rect.end.x - 1
	var coords = Geom.rect_perim(near_rect, near_side).filter(pred)
	if shuffle:
		coords.shuffle()
	return coords

