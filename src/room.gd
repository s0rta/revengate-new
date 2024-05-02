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
@export var layout_name:String
# sparse path compatible with Geom.interpolate_path(), empty for rectangular rooms
@export var layout_perim:Array[Vector2i]
# sparse: only the left most coord of a floor section that will continue right to the next wall
@export var floor_seeds:Array[Vector2i]
var position:Vector2i:
	get:
		return rect.position

static func from_layout(layout, offset:Vector2i):
	## Create an elaborate room with a shape described by a path
	## `layout`: a dict with at least `name`, `size`, `pillars`, and `floor_seeds`.
	## `layout.pillars` and `layout.floor_seeds` must be an Array of int pairs`
	## `offset`: where the top-left corner of the room's bounding box goes on the board.
	var room:Room = Room.new(Rect2i(offset, Vector2i(layout.size[0], layout.size[1])))
	room.layout_name = layout.name
	var path:Array[Vector2i] = []
	for pair in layout.pillars:
		path.append(Vector2i(pair[0], pair[1]))
	room.layout_perim = Geom.move_path(path, offset)
	var floor:Array[Vector2i] = []
	for pair in layout.floor_seeds:
		floor.append(Vector2i(pair[0], pair[1]))
	room.floor_seeds = Geom.move_path(floor, offset)	
	return room

func _init(rect_:Rect2i):
	rect = rect_

func get_center():
	return rect.get_center()

func has_coord(coord:Vector2i) -> bool:
	## Return whether `coord` is inside the room. Might interect with a wall.
	if not rect.has_point(coord):
		return false
	if layout_perim.is_empty():
		# rectangular room, we're done
		return true
	# see if we intersect with a wall in every cardinal direction
	var perim_coords = Utils.to_set(Geom.interpolate_path(layout_perim))
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var saw_perim = false
		var current = coord
		while rect.has_point(current):
			current += dir
			if perim_coords.has(current):
				saw_perim = true
				break
		if not saw_perim:
			return false
	return true

func new_door_coord(region=null) -> Vector2i:
	if layout_perim.is_empty():
		return Rand.coord_on_rect_perim(rect, region)
	else:
		var pillars = Utils.to_set(layout_perim)
		var coords = perim().filter(func (coord): return not pillars.has(coord))
		if region != null:
			coords = coords.filter(func (coord): return Geom.region_has_coord(rect, region, coord))
		return Rand.choice(coords)

func rand_coord() -> Vector2i:
	if layout_perim.is_empty():
		return Rand.coord_in_rect(rect)
	else:
		return Rand.choice(floor_coords())

func perim(corners=true, region=null):
	var coords:Array
	if layout_perim.is_empty():
		coords = Geom.rect_perim(rect, region)
		if not corners:
			coords = coords.filter(Geom.is_corner.bind(rect))
	else:
		coords = Geom.interpolate_path(layout_perim)
		if not corners:
			var all_corners = Utils.to_set(layout_perim)
			coords = coords.filter(func(coord): return not all_corners.has(coord))
		assert(region == null, "not implemented for layouts with region")
	return coords

func floor_coords() -> Array[Vector2i]:
	var coords:Array[Vector2i]
	if layout_perim.is_empty():
		var floor_rect = rect
		if has_walls:
			floor_rect = Geom.inner_rect(rect)
		coords = Geom.rect_coords(floor_rect)
	else:
		coords = []
		var current:Vector2i
		var perim_coords = Utils.to_set(Geom.interpolate_path(layout_perim))
		for seed in floor_seeds:
			current = seed
			while current not in perim_coords and rect.has_point(current):
				coords.append(current)
				current += Vector2i.RIGHT
	return coords
