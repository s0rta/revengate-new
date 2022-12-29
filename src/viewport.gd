# Copyright © 2022 Yannick Gingras <ygingras@ygingras.net> and contributors

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

func _input(event):
	if Input.is_action_just_pressed("zoom-in"):
		size_2d_override_stretch = true
		if size_2d_override == Vector2i.ZERO:
			size_2d_override = size
		size_2d_override /= 1.05
		set_input_as_handled()
	elif Input.is_action_just_pressed("zoom-out"):
		size_2d_override_stretch = true
		if size_2d_override == Vector2i.ZERO:
			size_2d_override = size
		size_2d_override *= 1.05
		set_input_as_handled()
	elif Input.is_action_pressed("pan"):
		if event is InputEventMouseMotion:
			var camera = get_camera_2d()
			camera.offset -= event.relative
		set_input_as_handled()
	elif not event is InputEventKey:
		# Pass all other pointer events to the sub-nodes, keys already propagate so we 
		# don't need to copy those.
		var new_event = event.duplicate()
		if new_event is InputEventMouseButton:
			new_event.position += get_camera_2d().offset
		push_unhandled_input(new_event, true)
