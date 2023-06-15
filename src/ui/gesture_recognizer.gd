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

const POS_EPSILON = 2.0  # positions that far apart are considered to be the same

@onready var viewport: SubViewport = find_child("Viewport")
var is_capturing_clicks := false
var has_panned := false
var was_long_tap := false

# multi-touch recognition
var nb_touching := 0
var touches_pos := {}  # event.index -> pos

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
	if is_capturing_clicks:
		if _is_tap_or_left_btn(event):
			accept_event()
			if event.pressed:
				emit_signal("capture_stopped", true, event.position)
	
func _gui_input(event):
	# The emulate_mouse_from_touch setting causes Godot to emit both an InputEventMouseButton and
	# an InputEventScreenTouch on mobile. The mouse event arrives first and we ignore it here to 
	# avoid doing touch actions twice. We can't do this filtering in _input() because HUD buttons
	# are blind to touch events and rely on on InputEventMouseButton 
	if OS.has_feature("mobile") and event is InputEventMouseButton:
		accept_event()
		return

	# TODO: MOUSE_BUTTON_RIGHT should pop the context menu

	# touch actions are treated like MOUSE_BUTTON_LEFT
	if _is_tap_or_left_btn(event):
		var index = event.get("index")
		if index == null:
			index = 0
		
		# TODO: we should accept the event to prevent any other controls from processing it, 
		#   but doing so silences all the events, even the ones that we are injecting into 
		#   the game viewport. Not sure how to work around that...
		# accept_event()
		if event.pressed:
			$LongTapTimer.stop()
			$LongTapTimer.start()
			touches_pos[index] = event.position
			nb_touching = len(touches_pos)
			if nb_touching == 1:
				has_panned = false
		else:  # release
			touches_pos.erase(index)
			nb_touching = len(touches_pos)
			if nb_touching == 0:
				if not has_panned: 
					# FIXME: only fire if hero is accepting
					if $LongTapTimer.time_left == 0:
						var context_event = ContextMenuEvent.new(event.position)
						viewport.inject_event(context_event)
					else:
						var act_event = ActEvent.new(event.position)
						viewport.inject_event(act_event)
						print("tap release: %s seconds left for a long tap" % $LongTapTimer.time_left)

	if nb_touching > 0 and (event is InputEventScreenDrag or event is InputEventMouseMotion):
		var index = event.get("index")
		if index == null:
			index = 0
		var info = _mt_info(index, event.position)
		if not info.center_eq:
			has_panned = true
			var camera = viewport.get_camera_2d()
			camera.offset -= event.relative
		if not info.avg_dist_eq:
			var factor = 1+(info.avg_dist_old - info.avg_dist_new) / info.avg_dist_old
			# re-zoom
			viewport.zoom *= factor
			touches_pos[index] = event.position
		accept_event()
	
	if event.is_action_pressed("zoom-in"):
		viewport.zoom_in()
	elif event.is_action_pressed("zoom-out"):
		viewport.zoom_out()
	# consume both zoom press and zoom release
	if event.is_action("zoom-in") or event.is_action("zoom-out"):
		accept_event()


func _unhandled_input(event):
	if is_capturing_clicks and event.is_action_released("ui_cancel"):
		emit_signal("capture_stopped", false, null)
		accept_event()

func _is_tap_or_left_btn(event):
	if event is InputEventScreenTouch:
		return true
	if not OS.has_feature("mobile"):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			return true
	return false

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
	info.center_new = info.center_old + (current_pos - touches_pos[current_index]) / nb_touching
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
