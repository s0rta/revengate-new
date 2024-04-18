# Copyright © 2023–2024 Yannick Gingras <ygingras@ygingras.net> and contributors

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

## Something that you can perceive as you go around the dungeon, but that you can't pick up.
@icon("res://assets/dcss/torch_1.png")
class_name Vibe extends Node2D

@export var char := ""
@export var caption := ""
@export var spawn_cost := 0.0
@export var spawn_rect:Rect2i
@export var tags:Array[String]

@export_group("Lights")
@export var light_col := Color(1, 1, 1, 1)

var shrouded := false  # partially or completely obscured
var _shroud_anim = null  # only one fading going on at a time

func _ready():
	$Label.text = char
	Utils.assert_all_tags(tags)
	Utils.hide_unplaced(self)
	
	var lights = find_children("", "PointLight2D", false, true)
	for light in lights:
		light.color = light_col
		if light.name.begins_with("Long"):
			_start_flicker(light)

func get_board():
	var parent = get_parent()
	if parent is RevBoard:
		return parent
	else:
		return null

func get_cell_coord() -> Vector2i:
	## Return the board coord of the vibe or null if the vibe has not been placed.
	var parent = get_parent()
	if parent is RevBoard:
		return RevBoard.canvas_to_board(position)
	else:
		return Consts.COORD_INVALID

func get_short_desc():
	return caption

func place(coord, _immediate=null):
	## Place the vibe at the specific coordinate without animations.
	## No tests are done to see if `coord` is a suitable location.
	## _immediate: ignored.
	position = RevBoard.board_to_canvas(coord)

func activate():
	## The Vibe just got noticed, so make that obvious
	if caption.is_empty():
		return  # turns out this vibe is really subtle...
	Tender.hero.add_message("You notice %s" % get_short_desc())
	
func is_unexposed(index=null):
	## Return if this vibe is where the hero should could be aware of them
	
	# on a board other than the active one
	var parent = get_parent()
	if parent == null or not parent is RevBoard or not parent.visible:
		return true

	# out of sight
	if Tender.hero and not Tender.hero.perceives(self, index):
		return true

	return false

func should_hide(index=null):
	var parent = get_parent()
	if not parent is RevBoard:
		return true
	if index == null:
		index = parent.make_index()
	var here = get_cell_coord()
	if self != index.top_vibe_at(here):
		return true
	else:
		return false

func should_shroud(index=null):
	return is_unexposed(index)

func shroud(animate=true):
	Utils.shroud_node(self, animate)
		
func unshroud(animate=true):
	Utils.unshroud_node(self, animate)

func _start_flicker(light):
	# FIXME: this would look better if we kept both Long and Short lights in sync
	var old_energy = light.energy
	var low_energy = randf_range(0.0, old_energy/2.0)
	var tween = create_tween()
	var anim_time = randf_range(0.1, 0.8)
	tween.tween_property(light, "energy", low_energy, anim_time)
	tween.tween_property(light, "energy", old_energy, anim_time)
	tween.finished.connect(_start_flicker.bind(light), CONNECT_ONE_SHOT)
