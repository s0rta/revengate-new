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

func _ready():
	# we set those here because the parent container tends to override them in the scene editor
	if size_2d_override == Vector2i.ZERO:
		size_2d_override = size
	size_2d_override_stretch = true

func inject_event(event, manual_xform=true):
	## Send an input even to our descendent nodes.
	## manual_xform: compute reposition manually, useful for custom event types that 
	##   Viewport.push_event() doen't know how to tranform.
	var offset = get_camera_2d().offset
	if manual_xform and event.get("position"):
		# TODO: we might be able to use InputEvent.xformed_by()
		var transform = get_final_transform().affine_inverse()
		event.position = event.position * transform + offset
	elif event is InputEventMouseButton:
		event.position -= offset
	push_unhandled_input(event, not manual_xform)

func _on_zoom_slider_value_changed(value):
	size_2d_override = size / value

func center_on_coord(coord):
	## move the camera to be directly above `coord`
	var pos = RevBoard.board_to_canvas(coord)
	var transform = get_final_transform().affine_inverse()
	var camera = get_camera_2d()
	
	camera.offset = pos - size/2.0*transform
	
