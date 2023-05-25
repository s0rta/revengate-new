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

## Recognize some basic gestures and pass selectively them to the Game Area Viewport.
class_name GestureRecognizer extends SubViewportContainer
signal capture_stopped(success, position)
signal action_started(message)
signal action_complete

@onready var viewport: SubViewport = find_child("Viewport")
var is_capturing_clicks := false
var has_panned := false
var was_long_tap := false

## Act on Cell: do the default action for a particular tile.
class ActEvent extends InputEventAction:
	var position

	func _init(position_, pressed_=true):
		action = "act-on-cell"
		position = position_
		pressed = pressed_

	func ddump():
		return "ActEvent: action=%s, pressed=%s, pos=%s, coord=%s" % [action, pressed, position, RevBoard.canvas_to_board_str(position)]

## Loot exactly where the hero is currently standing
class LootEvent extends InputEventAction:
	func _init(pressed_=true):
		action = "loot-here"
		pressed = pressed_

	func ddump():
		return "LootEvent: action=%s, pressed=%s" % [action, pressed]

## Show the inventory screen
class InventoryEvent extends InputEventAction:
	func _init(pressed_=true):
		action = "show-inventory"
		pressed = pressed_

	func ddump():
		return "InventoryEvent: action=%s, pressed=%s" % [action, pressed]

## Show a context menu
class ContextMenuEvent extends InputEventAction:
	var position

	func _init(position_, pressed_=true):
		action = "context-menu"
		position = position_
		pressed = pressed_

	func ddump():
		return "ContextMenuEvent: action=%s, pressed=%s" % [action, pressed]


func _input(event):
	if is_capturing_clicks and event is InputEventMouseButton:
		accept_event()
		if not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			emit_signal("capture_stopped", true, event.position)

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.pressed and event.double_click:
			# BUG: Our current implementation of doubletap actions is wrong because single tap
			# actions have already been done by the time this handler is called. 
			print("Double tap is not implemented, ignoring...")
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			$LongTapTimer.stop()
			$LongTapTimer.start()
		elif not has_panned and event.button_index == MOUSE_BUTTON_LEFT:  # release
			# FIXME: only fire if hero is accepting
			if $LongTapTimer.time_left == 0:
				var context_event = ContextMenuEvent.new(event.position)
				viewport.inject_event(context_event)
				accept_event()
			else:
				print("tap release: %s seconds left for a long tap" % $LongTapTimer.time_left)
		
	if event.is_action_pressed("pan"):
		has_panned = false
		accept_event()
	elif event.is_action_released("pan"):
		if has_panned:
			accept_event()
		else:
			# FIXME: we should stop propagating the click, but accept_event() kills *any* event, 
			#   including the accept action.
			# accept_event()  
			var act_event = ActEvent.new(event.position)
			viewport.inject_event(act_event)
		
	if Input.is_action_pressed("pan"):
		if event is InputEventMouseMotion:
			has_panned = true
			var camera = viewport.get_camera_2d()
			camera.offset -= event.relative
		accept_event()

func _unhandled_input(event):
	if is_capturing_clicks and event.is_action_released("ui_cancel"):
		emit_signal("capture_stopped", false, null)
		accept_event()

func start_loot():
	## Start the loot action, pass the control to Hero
	var event = LootEvent.new()
	viewport.inject_event(event)

func start_inspect_at():
	is_capturing_clicks = true
	emit_signal("action_started", "select position...")
	var vals = await capture_stopped
	emit_signal("action_complete")
	if vals[0]:
		var coord = viewport.global_pos_to_board_coord(vals[1])
		$/root/Main.commands.inspect(coord)
	is_capturing_clicks = false

func show_inventory():
	## Start the loot action, pass the control to Hero
	var event = InventoryEvent.new()
	viewport.inject_event(event)

func ddump():
	var transform = viewport.get_final_transform()
	var cam = viewport.get_camera_2d()
	print("transform is: %s" % transform)
	print("cam offset is: %s %s" % [cam.offset, RevBoard.canvas_to_board_str(cam.offset)])
