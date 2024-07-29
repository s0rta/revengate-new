# Copyright © 2022-2024 Yannick Gingras <ygingras@ygingras.net> and contributors

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

## A sub-class of viewport that makes it easy to remap game commands to the 
## zoomed and panned game board.
extends SubViewport
var tabulator := Tabulator.load()

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

func pos_to_local(pos, apply_camera:=true):
	## Convert a screen pixel `pos` into to a local pixel `pos`
	var offset = Vector2.ZERO
	if apply_camera:
		offset = get_camera_2d().offset
	var transform = get_final_transform().affine_inverse()
	return pos * transform + offset

func global_pos_to_board_coord(pos):
	## Convert a screen pixel `pos` into a Board tile `coord`.
	return RevBoard.canvas_to_board(pos_to_local(pos))

func zoom_in(focal_point=null, factor:=1.05):
	## Increase magnification
	if focal_point == null:
		focal_point = size/2.0
	var old_focus = pos_to_local(focal_point, false)
	zoom *= factor
	var new_focus = pos_to_local(focal_point, false)
	var camera = get_camera_2d()
	camera.offset += old_focus - new_focus
	
func zoom_out(focal_point=null, factor:=1.05):
	## Decrease magnification
	zoom_in(focal_point, 1.0/factor)

func inject_event(event):
	## Send an input even to our descendent nodes.
	## manual_xform: compute reposition manually, useful for custom event types that 
	##   Viewport.push_event() doen't know how to tranform.
	if event.get("position"):
		# TODO: we might be able to use InputEvent.xformed_by()
		event.position = pos_to_local(event.position)
	elif event is InputEventMouseButton:
		event.position -= get_camera_2d().offset
	
	if Tender.hero and Tender.hero.is_alive():
		# This is a performance optimization since the Hero is the only node 
		# that is dealing with events in the Main game.
		Tender.hero._unhandled_input(event)
	else:
		# or it might be a Hero-free simulation...
		push_input(event, false)

func center_on_coord(coord):
	## move the camera to be directly above `coord`
	# FIXME: deprecate
	var pos = RevBoard.board_to_canvas(coord)
	var camera = get_camera_2d()
	camera.offset = pos - pos_to_local(size/2.0, false)

func pan_on_coord(coord, to_pos=null, anim_secs:=0.0):
	## move the camera so that the board cell at 'coord' is at 'to_tos' on the screen.
	## to_pos: center of the screen if not provided
	## anim_secs: how long to take to animate the transion, 0.0 for instant effect
	if to_pos == null:
		to_pos = size / 2.0
	else:
		assert(to_pos is Vector2 or to_pos is Vector2i)

	var from_pos = RevBoard.board_to_canvas(coord)
	var new_offset = from_pos - pos_to_local(to_pos, false)
	var camera = get_camera_2d()
	
	if anim_secs > 0.0:
		var anim = create_tween()
		anim.tween_property(camera, "offset", new_offset, anim_secs)
	else:
		camera.offset = new_offset

func flash_coord_selection(coord:Vector2i):
	var highlight = load("res://src/ui/cell_highlight.tscn").instantiate()
	highlight.position = RevBoard.board_to_canvas(coord)
	add_child(highlight)
	Utils.fadeout_later(highlight, 5)

func effect_at_coord(effect, coord:Vector2i, fadeout_secs:=0):
	if effect is String:
		effect = load(Utils.effect_path(effect)).instantiate()
	effect.position = RevBoard.board_to_canvas(coord)
	effect.skip_shader = effect.skip_shader or not tabulator.enable_shaders
	add_child(effect)
	if fadeout_secs:
		Utils.fadeout_later(effect, fadeout_secs)

func effect_between_coords(effect, start_coord:Vector2i, end_coord:Vector2i, fadeout_secs:=0):
	if effect is String:
		effect = load(Utils.effect_path(effect)).instantiate()
	effect.start_coord = start_coord
	effect.end_coord = end_coord
	var start_pos = RevBoard.board_to_canvas(start_coord)
	var end_pos = RevBoard.board_to_canvas(end_coord)
	effect.position = (start_pos + end_pos) / 2.0
	effect.skip_shader = effect.skip_shader or not tabulator.enable_shaders
	add_child(effect)
	if fadeout_secs:
		Utils.fadeout_later(effect, fadeout_secs)
