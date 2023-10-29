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
					"p": PassageFab, 
					"c": ChurchFab}

class Prefab extends RefCounted:
	var builder: BoardBuilder
	var rect:Rect2i  # The bigger rect that the region is computed against
	var region
	var fab_rect:Rect2i  # The smaller rect that will be populated by this PreFab
	var caption:String  # What is this prefab all about? For debug purposes only.
	
	# TODO: we should store instances instead so fabs can modify them
	var mandatory_card_paths = []
	var optional_card_paths = []
	
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

	func _instantiate_card(path):
		return load(path).instantiate()

	func get_mandatory_cards():
		## Return cards that should be drawn when populating the board where this PreFab is placed.
		return mandatory_card_paths.map(_instantiate_card)

	func get_optional_cards():
		## Return cards that should be added to the probabilistic decks when populating the board
		## where this PreFab is placed.
		return optional_card_paths.map(_instantiate_card)

	
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

	func get_untouched_rect():
		# this fab is unobtrusive enough to not modify the drawing area
		return rect
		
class ChurchFab extends Prefab:
	# the wall outside the church
	var wall_path = V.arr_i([[5, 13], [4, 13], [4, 12], [2, 12], [2, 10], [4, 10], 
							[4, 4], [5, 4], [5, 3], [6, 3], [6, 2],
							[7, 2], [7, 3], [8, 3], [8, 4], [9, 4], 
							[9, 10], [11, 10], [11, 12], [9, 12], [9, 13], [7, 13]])
	var tower_cores = V.arr_i([[3, 11], [10, 11]])
	var nave:Rect2i

	func _init(builder, rect, region):
		super(builder, rect, region)
		caption = "church"
		fab_rect = Rect2i(0, 0, 14, 16)
		var wiggle_room = rect.size - fab_rect.size
		fab_rect.position = rect.position
		assert(rect.encloses(fab_rect))
		
		mandatory_card_paths.append("res://src/vibes/altar.tscn")
		mandatory_card_paths.append("res://src/vibes/cross.tscn")
		mandatory_card_paths.append("res://src/people/priest.tscn")

		optional_card_paths.append("res://src/vibes/fancy_cross.tscn")
		optional_card_paths.append("res://src/vibes/incense.tscn")
		optional_card_paths.append("res://src/vibes/incense.tscn")
		optional_card_paths.append("res://src/vibes/candles.tscn")
		optional_card_paths.append("res://src/vibes/candles.tscn")
		optional_card_paths.append("res://src/vibes/stained_glass.tscn")
		
		# TODO: transpose if needed to match the long side of the region
		if region == Consts.REG_NORTH:
			fab_rect.position.x += randi_range(0, wiggle_room.x - 1)
		elif region == Consts.REG_SOUTH:
			fab_rect.position.y += wiggle_room.y			
			fab_rect.position.x += randi_range(0, wiggle_room.x - 1)
		elif region == Consts.REG_WEST:
			fab_rect.position.y += randi_range(0, wiggle_room.y - 1)
		elif region == Consts.REG_EAST:
			fab_rect.position.x += wiggle_room.x			
			fab_rect.position.y += randi_range(0, wiggle_room.y - 1)
		else:
			assert(false, "Not implemented!")
			
		wall_path = Geom.move_path(wall_path, fab_rect.position)
		nave = Geom.inner_rect(fab_rect, 4)
		nave.size.y += 3
		
	func fill():
		var board = builder.board
		board.paint_path(wall_path, "wall")
		_add_stairs(fab_rect.position + Rand.choice(tower_cores))
		
	func _add_stairs(where):
		builder.board.paint_cell(where, "stairs-down")
		var new_world_loc = builder.board.world_loc + Consts.LOC_LOWER
		var rec = {"dungeon": "Crypt", 
				"world_loc": new_world_loc, 
				"depth": builder.board.depth + 1}
		builder.board.set_cell_rec(where, "conn_target", rec)
		
	func get_untouched_rect():
		var wiggle_room = rect.size - fab_rect.size
		if region == Consts.REG_NORTH:
			return Rect2i(rect.position.x, rect.position.y + fab_rect.size.y, 
							rect.size.x, wiggle_room.y)
		elif region == Consts.REG_SOUTH:
			return Rect2i(rect.position.x, rect.position.y, 
							rect.size.x, wiggle_room.y)
		elif region == Consts.REG_WEST:
			return Rect2i(rect.position.x + fab_rect.size.x, rect.position.y, 
							wiggle_room.x, rect.size.y)
		elif region == Consts.REG_EAST:
			return Rect2i(rect.position.x, rect.position.y, 
							wiggle_room.x, rect.size.y)
		else:
			assert(false, "Not implemented!")
	
	func _spawn_in_nave(cards):
		## Move the spawn rect of all cards to be inside the church nave.
		for card in cards:
			if card.get("spawn_rect") != null:
				card.spawn_rect = nave
		return cards		

	func get_mandatory_cards():
		return _spawn_in_nave(super())

	func get_optional_cards():
		return _spawn_in_nave(super())


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
	
