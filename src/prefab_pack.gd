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
const _fab_chars := {"r": RiverFab}

class Prefab extends RefCounted:
	var builder
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
	var cross_axis:int
	var flow_axis:int
	
	func _init(builder, rect, region):
		super(builder, rect, region)
		caption = "river"
		if region == Consts.REG_NORTH or region == Consts.REG_SOUTH:
			cross_axis = Vector2i.AXIS_Y
			flow_axis = Vector2i.AXIS_X
		else:
			cross_axis = Vector2i.AXIS_X
			flow_axis = Vector2i.AXIS_Y
		var cross_side = _cross_dim()
		assert(cross_side >= 1, "Region is too small for a river")
		if cross_side >= 3:
			span = 2
		else:
			span = 1

	func fill():
		var step_vec: Vector2i
		var bend_vec: Vector2i
		if region == Consts.REG_NORTH or region == Consts.REG_SOUTH:
			# horizontal river
			step_vec = Vector2i.RIGHT
			bend_vec = Vector2i.DOWN
		else:
			# veritical river
			step_vec = Vector2i.DOWN
			bend_vec = Vector2i.RIGHT
		var near_limit = fab_rect.position[cross_axis]  # the side that is closer to the origin
		var far_limit = fab_rect.end[cross_axis] - 1  # the side further away from the origin

		# where the water starts
		var near_edge = randi_range(0, fab_rect.size[cross_axis]-span-1)
		
		for k in fab_rect.size[flow_axis]:
			var coords = []
			for i in span:
				coords.append(fab_rect.position + step_vec*k + bend_vec*(near_edge+i))
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
				coords.append(fab_rect.position + step_vec*k + bend_vec*pad_edge)
			builder.paint_cells(coords, "water")
			near_edge += shift
		
	func _cross_dim():
		## Return how big our available rect is on the side perpendicular to the river flow
		return fab_rect.size[cross_axis]
		
	func _flow_dim():
		## Return how big our available rect is on the side parallel to the river flow
		return fab_rect.size[flow_axis]

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
		if rect == null or rect.encolses(frect):
			rect = frect
	return rect

static func ddump():
	print("Registered prefab characters are: %s" % [_fab_chars.keys()])
	
