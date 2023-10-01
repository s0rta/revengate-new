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

## Canned components of game boards 
class_name PrefabPack extends RefCounted

# {char -> fab_class}
const _fab_chars := {"r": RiverFab, 
					"p": PassageFab}

class Prefab extends RefCounted:
	var builder: BoardBuilder
	var rect:Rect2i  # The bigger rect that the region is computed against
	var region
	var fab_rect:Rect2i  # The smaller rect that will be populated by this PreFab
	var caption:String  # What is this prefab all about? For debug purposes only.
	
	func _init(builder_, rect_, region_=null):
		builder = builder_
		rect = rect_
		region = region_
		if region != null:
			fab_rect = Geom.region_bounding_rect(rect, region)
		else:
			fab_rect = rect
	
	func _to_string():
		return "<PreFab %s on %s>" % [caption, fab_rect]

	func fill():
		## Fill our `rect` with the pre-fap pattern.
		## Must be overloaded by base classes.
		assert(false, "Not implemented")

	func get_untouched_rect():
		## Return the part of the origninal rect that was not under consideration for fabbing.
		if region == null or region == Consts.REG_CENTER:
			return null
		return Geom.region_outside_rect(rect, region)
	
class RiverFab extends Prefab:
	var span:int  # average distance between river banks
	var cross_axis:int  # perpendicular to the river flow
	var flow_axis:int  # parallel to the river flow
	var flow_step:Vector2i
	var cross_step:Vector2i
	
	func _init(builder, rect, region):
		super(builder, rect, region)
		caption = "river"
		if region == Consts.REG_NORTH or region == Consts.REG_SOUTH:
			# horizontal river
			cross_axis = Vector2i.AXIS_Y
			flow_axis = Vector2i.AXIS_X
			flow_step = Vector2i.RIGHT
			cross_step = Vector2i.DOWN
		else:
			# veritical river
			cross_axis = Vector2i.AXIS_X
			flow_axis = Vector2i.AXIS_Y
			flow_step = Vector2i.DOWN
			cross_step = Vector2i.RIGHT
		var cross_side = _cross_dim()
		assert(cross_side >= 1, "Region is too small for a river")
		if cross_side >= 3:
			span = 2
		else:
			span = 1

	func fill():
		var near_limit = fab_rect.position[cross_axis]  # the side that is closer to the origin
		var far_limit = fab_rect.end[cross_axis] - 1  # the side further away from the origin

		# where the water starts
		var near_edge = randi_range(0, fab_rect.size[cross_axis]-span-1)
		
		for k in fab_rect.size[flow_axis]:
			var coords = []
			for i in span:
				coords.append(fab_rect.position + flow_step*k + cross_step*(near_edge+i))
			var shifts = [0]  # where the banks can move for the next step
			if near_edge > 0:
				shifts.append(-1)
			if near_edge+span < fab_rect.size[cross_axis] - 1:
				shifts.append(1)
			var shift = Rand.biased_choice(shifts, 3)
			if shift:
				# add a bit more water at the bend to soften the turn
				var pad_edge
				if shift < 0:
					pad_edge = near_edge + shift
				else:
					pad_edge = near_edge + span
				coords.append(fab_rect.position + flow_step*k + cross_step*pad_edge)
			builder.board.paint_cells(coords, "water")
			near_edge += shift
		_clear_beyond_land()
		
	func _cross_dim():
		## Return how big our available rect is on the side perpendicular to the river flow
		return fab_rect.size[cross_axis]
		
	func _flow_dim():
		## Return how big our available rect is on the side parallel to the river flow
		return fab_rect.size[flow_axis]

	func _clear_beyond_land():
		## Clear all the terrain between the river and the edge of the map
		var cross_vect = -region
		var sign = cross_vect[cross_axis]
		var cross_start_step = 0
		if sign < 0:
			cross_start_step = fab_rect.size[cross_axis] - 1 
		for k in fab_rect.size[flow_axis]:
			for i in fab_rect.size[cross_axis]:
				var cross_delta = (i*sign + cross_start_step) * cross_step
				var coord = fab_rect.position + flow_step*k + cross_delta
				if builder.board.get_cell_terrain(coord) == "water":
					break
				else:
					builder.board.erase_cell(0, coord)

class PassageFab extends Prefab:
	func _init(builder, rect, region):
		super(builder, rect, region)
		caption = "passage"

	func fill():
		var where = null
		assert(region != Consts.REG_CENTER, 
				"PassageFab only supports peripheral connectors for now.")
		where = Rand.coord_on_rect_perim(builder.rect, region)
			
		builder.board.paint_cell(where, "gateway")
		var new_world_loc = Vector3i(region.x, region.y, 0) + builder.board.world_loc
		var rec = {"dungeon": "TroisGaulesSurface", 
				"world_loc": new_world_loc, 
				"depth": builder.board.depth + 1}
		builder.board.set_cell_rec(where, "conn_target", rec)

static func parse_fabstr(fabstr:String, builder:BoardBuilder, rect=null):
	## Return a list of prefab instances for fabstr.
	if fabstr.is_empty():
		return []
	if rect == null:
		rect = builder.rect
	var fabs = []
	var region = null
	var nb_char = 0
	for char in fabstr:
		nb_char += 1
		assert(nb_char <= 2, "Only one region qualifier allower before a fab char.")
		if Consts.REGION_CHARS.has(char):
			region = Consts.REGION_CHARS[char]
		elif _fab_chars.has(char):
			var fab = _fab_chars[char].new(builder, rect, region)
			var untouched = fab.get_untouched_rect()
			if untouched != null:
				rect = untouched
			fabs.append(fab)
			region = null
			nb_char = 0
		else:
			assert(false, "%s in %s is neighter a region nor a fab character!" % [char, fabstr])
	assert(_fab_chars.has(fabstr[-1]), "Last fabstr element must be a fab char!")
	return fabs			

static func fabs_untouched_rect(fabs):
	## Return the smallest untouched rect for all fabs in an array
	var rect = null
	for fab in fabs:
		var frect = fab.get_untouched_rect()
		if frect == null:
			continue
		if rect == null or rect.encloses(frect):
			rect = frect
	return rect

static func ddump():
	print("Registered prefab characters are: %s" % [_fab_chars.keys()])
	
