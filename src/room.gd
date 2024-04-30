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

## a template for a room, used while building a board
class_name Room extends Resource

@export var rect: Rect2i
@export var has_walls := true
var position:Vector2i:
	get:
		return rect.position

static func from_rect(rect_:Rect2i) -> Room:
	var room:Room = Room.new()
	room.rect = rect_
	return room
	
static func from_layout():
	pass

func get_center():
	return rect.get_center()

func has_coord(coord:Vector2i):
	return rect.has_point(coord)

func new_door_coord(region=null):	
	return Rand.coord_on_rect_perim(rect, region)

func rand_coord() -> Vector2i:
	return Rand.coord_in_rect(rect)

func perim(corners=true, region=null):
	var coords = Geom.rect_perim(rect, region)
	if not corners:
		coords = coords.filter(Geom.is_corner.bind(rect))
	return coords

func floor_coords() -> Array[Vector2i]:
	var floor_rect = rect
	if has_walls:
		floor_rect = Geom.inner_rect(rect)
	return Geom.rect_coords(floor_rect)
	
