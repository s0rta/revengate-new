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
signal capture_stopped(result:CaptureResult)
signal action_started(message)
signal action_complete

# positions are considered the same unless at least that far apart
const POS_EPSILON = 2.0  

@onready var viewport: SubViewport = find_child("Viewport")
var is_processing := false  # are we in the middle of a gesture?
var is_capturing_clicks := false
var valid_capture_coords = null
var is_panning := false
var has_panned := false
var was_long_tap := false

# multi-touch recognition
var nb_touching := 0
var touches_pos := {}  # event.index -> pos

class CaptureResult extends RefCounted:
	## The result of attempting to capture the next gesture
	var success: bool  # did the capture work or was it cancelled?
	var pos: Vector2  # the screen position in pixels
	var coord: Vector2i  # the board coordinate in tiles
	
	func _init(success_:bool, pos_=null, coord_=null):
		success = success_
		if pos_:
			pos = pos_
		if coord_:
			coord = coord_

## Act on Cell: do the default action for a particular tile.
class ActEvent extends InputEventAction:
	var position

	func _init(position_, pressed_=true):
		action = "act-on-cell"
		position = position_
		pressed = pressed_

	func ddump():
		return "ActEvent: action=%s, pressed=%s, pos=%s, coord=%s" % [
				action, pressed, position, RevBoard.canvas_to_board_str(position)
			]

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

func _ready():
	$LongTapTimer.wait_time = UIUtils.LONG_TAP_SECS

func _input(event):
	if _attempt_capture(event):
		return
	
func _gui_input(event):
	# The emulate_mouse_from_touch setting causes Godot to emit both an InputEventMouseButton and
	# an InputEventScreenTouch on mobile. The mouse event arrives first and we ignore it here to 
	# avoid doing touch actions twice. We can't do this filtering in _input() because HUD buttons
	# are blind to touch events and rely on on InputEventMouseButton 
	if OS.has_feature("mobile") and event is InputEventMouseButton:
		accept_event()
		return

	if _attempt_capture(event):
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		# context menu on right click
		is_processing = false
		accept_event()
		show_context_menu_for(event.position)
	elif Utils.event_is_tap_or_left(event):
		# touch actions are treated like MOUSE_BUTTON_LEFT
		var index = event.get("index")
		if index == null:
			index = 0
		
		accept_event()
		if event.pressed:
			is_processing = true
			$LongTapTimer.stop()
			touches_pos[index] = event.position
			nb_touching = len(touches_pos)
			if nb_touching == 1:
				$LongTapTimer.start()
				is_panning = false
				has_panned = false
		else:  # release
			touches_pos.erase(index)
			nb_touching = len(touches_pos)
			if nb_touching == 0:
				is_processing = false
				is_panning = false
				if not has_panned:
					if $LongTapTimer.time_left > 0:
						# didn't hold long enough to make it a long tap
						var act_event = ActEvent.new(event.position)
						viewport.inject_event(act_event)
						print("tap release: %s seconds left for a long tap" % $LongTapTimer.time_left)
				$LongTapTimer.stop()

	if (is_processing and nb_touching > 0 
			and (event is InputEventScreenDrag or event is InputEventMouseMotion)):
		var index = event.get("index")
		if index == null:
			index = 0
		var info = _mt_info(index, event.position)
		if is_panning or not info.center_eq:
			is_panning = true
			has_panned = true
			var camera = viewport.get_camera_2d()
			camera.offset -= ((info.center_new - info.center_old) * viewport.zoom)
			touches_pos[index] = event.position
		if not info.avg_dist_eq:
			var factor = 1+(info.avg_dist_old - info.avg_dist_new) / info.avg_dist_old
			# re-zoom
			viewport.zoom_in(info.center_new, factor)
			touches_pos[index] = event.position
		accept_event()
	
	if event.is_action_pressed("zoom-in"):
		viewport.zoom_in(event.position)
	elif event.is_action_pressed("zoom-out"):
		viewport.zoom_out(event.position)
	# consume both zoom press and zoom release
	if event.is_action("zoom-in") or event.is_action("zoom-out"):
		accept_event()

func _unhandled_input(event):
	if is_capturing_clicks and event.is_action_pressed("ui_cancel"):
		var res = CaptureResult.new(false)
		emit_signal("capture_stopped", res)
		accept_event()

func _attempt_capture(event):
	## Try to capture event (possibly for a multi-tap action that is awaiting on it).
	## Return where the event was indeed captured.
	if is_capturing_clicks:
		Utils.ddump_event(event, self, "_attempt_capture")
		if Utils.event_is_tap_or_left(event):
			accept_event()
			if event.pressed:
				var success:bool
				var coord = viewport.global_pos_to_board_coord(event.position)
				if valid_capture_coords and coord not in valid_capture_coords:
					success = false
				else:
					success = true
				var res = CaptureResult.new(success, event.position, coord)
				capture_stopped.emit(res)
			return true
	return false

func _on_long_tap_timer_timeout():
	if not is_capturing_clicks and nb_touching == 1 and not has_panned:
		is_processing = false
		print("New long tap handler")
		var pos = touches_pos.values()[0]
		show_context_menu_for(pos)

func _mt_info(current_index, current_pos):
	## Return a dictionary of information about the current multi-touch event
	var info = {}
	var total = Vector2.ZERO
	for index in touches_pos:
		total += touches_pos[index]
	info.center_old = total / nb_touching
	total = 0.0
	for index in touches_pos:
		total += info.center_old.distance_to(touches_pos[index])
	info.avg_dist_old = total / nb_touching
	if touches_pos.has(current_index):
		info.center_new = info.center_old + (current_pos - touches_pos[current_index]) / nb_touching
	else:
		info.center_new = info.center_old
	total = 0.0
	for index in touches_pos:
		if index == current_index:
			total += info.center_new.distance_to(current_pos)
		else:
			total += info.center_new.distance_to(touches_pos[index])
	info.avg_dist_new = total / nb_touching
	info.center_eq = info.center_old.distance_to(info.center_new) < POS_EPSILON
	info.avg_dist_eq = abs(info.avg_dist_old - info.avg_dist_new) < POS_EPSILON
	return info

func start_capture_coord(msg, coords=null) -> CaptureResult:
	## Capture the next click
	## `coords`: if provided, only consider success if the click is in one of those
	is_capturing_clicks = true
	valid_capture_coords = coords
	emit_signal("action_started", msg)
	var res = await capture_stopped
	is_capturing_clicks = false
	valid_capture_coords = null
	emit_signal("action_complete")
	return res

func start_inspect_at():
	var res = await start_capture_coord("select position...")
	if res.success:
		$/root/Main.commands.inspect(res.coord)

func show_inventory():
	## Start the loot action, pass the control to Hero
	var event = InventoryEvent.new()
	viewport.inject_event(event)

func show_context_menu_for(pos):
	var context_event = ContextMenuEvent.new(pos)
	viewport.inject_event(context_event)
	
func ddump():
	var transform = viewport.get_final_transform()
	var cam = viewport.get_camera_2d()
	print("transform is: %s" % transform)
	print("cam offset is: %s %s" % [cam.offset, RevBoard.canvas_to_board_str(cam.offset)])

