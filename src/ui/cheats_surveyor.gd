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

## Monitor multi-events gestures that can results in cheats
class_name CheatsSurveyor extends Control

# TODO: get a ref to the board viewport, but we can't use @onready because we are ready before it
var is_capturing := false
signal capture_stopped(success, position)
signal action_started(message)
signal action_complete

func start_teleport_to():
	is_capturing = true
	emit_signal("action_started", "select position...")
	var vals = await capture_stopped
	emit_signal("action_complete")
	if vals[0]:
		var viewport = $/root/Main.find_child("Viewport")
		var pos = viewport.pos_to_local(vals[1])
		var coord = RevBoard.canvas_to_board(pos)
		get_parent().hero.place(coord, true)
	is_capturing = false

func start_inspect_at():
	is_capturing = true
	emit_signal("action_started", "select position...")
	var vals = await capture_stopped
	emit_signal("action_complete")
	if vals[0]:
		var viewport = $/root/Main.find_child("Viewport")
		var pos = viewport.pos_to_local(vals[1])
		var coord = RevBoard.canvas_to_board(pos)
		var board = $/root/Main.get_board()
		print("Board.is_in_rect(%s): %s" % [board.coord_str(coord), board.is_on_board(coord)])
		var data = board.get_cell_tile_data(0, coord)
		print("Data here is %s" % [[var_to_str(data), data.get_custom_data
	("is_connector")]])
	is_capturing = false

func _input(event):
	if is_capturing and event is InputEventMouseButton:
		accept_event()
		if not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			emit_signal("capture_stopped", true, event.position)

func _unhandled_input(event):
	# TODO: collapse the cheats button bar if open and no action to cancel
	if is_capturing and event.is_action_released("ui_cancel"):
		emit_signal("capture_stopped", false, null)
		accept_event()
	elif event.is_action_released("cheat-teleport-to"):
		start_teleport_to()
		accept_event()
	elif event.is_action_released("cheat-inspect-at"):
		start_inspect_at()
		accept_event()