# Copyright © 2022-2023 Yannick Gingras <ygingras@ygingras.net> and contributors

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

extends SubViewport

var zoom := 1.0:
	get:
		return zoom
	set(new_zoom):
		zoom = new_zoom
		size_2d_override = size * zoom

func _ready():
	# we set those here because the parent container tends to override them in the scene editor
	if size_2d_override == Vector2i.ZERO:
		size_2d_override = size
	size_2d_override_stretch = true

func pos_to_local(pos):
	## Convert a screen pixel `pos` into to a local pixel `pos`
	var offset = get_camera_2d().offset
	var transform = get_final_transform().affine_inverse()
	return pos * transform + offset

func zoom_in(factor:=1.05):
	## Increase magnification
	zoom *= factor
	
func zoom_out(factor:=1.05):
	## Decrease magnification
	zoom /= factor

func global_pos_to_board_coord(pos):
	## Convert a screen pixel `pos` into a Board tile `coord`.
	return RevBoard.canvas_to_board(pos_to_local(pos))

func inject_event(event, manual_xform=true):
	## Send an input even to our descendent nodes.
	## manual_xform: compute reposition manually, useful for custom event types that 
	##   Viewport.push_event() doen't know how to tranform.
	var offset = get_camera_2d().offset
	if manual_xform and event.get("position"):
		# TODO: we might be able to use InputEvent.xformed_by()
		#   - use pos_to_local()
		var transform = get_final_transform().affine_inverse()
		event.position = event.position * transform + offset
	elif event is InputEventMouseButton:
		event.position -= offset
	push_unhandled_input(event, not manual_xform)

func center_on_coord(coord):
	## move the camera to be directly above `coord`
	var pos = RevBoard.board_to_canvas(coord)
	var transform = get_final_transform().affine_inverse()
	var camera = get_camera_2d()
	
	camera.offset = pos - size/2.0*transform
	
func flash_coord_selection(coord:Vector2i):
	var highlight = load("res://src/ui/cell_highlight.tscn").instantiate()
	highlight.position = RevBoard.board_to_canvas(coord)
	add_child(highlight)
	Utils.fadeout_later(highlight, 5)

func effect_at_coord(effect_name, coord:Vector2i, fadeout_secs:=0):
	var effect = load(Utils.effect_path(effect_name)).instantiate()
	effect.position = RevBoard.board_to_canvas(coord)
	add_child(effect)
	if fadeout_secs:
		Utils.fadeout_later(effect, fadeout_secs)

func effect_between_coords(effect_name, start_coord:Vector2i, end_coord:Vector2i, fadeout_secs:=0):
	var effect = load(Utils.effect_path(effect_name)).instantiate()
	effect.start_coord = start_coord
	effect.end_coord = end_coord
	var start_pos = RevBoard.board_to_canvas(start_coord)
	var end_pos = RevBoard.board_to_canvas(end_coord)
	effect.position = (start_pos + end_pos) / 2.0
	add_child(effect)
	if fadeout_secs:
		Utils.fadeout_later(effect, fadeout_secs)
