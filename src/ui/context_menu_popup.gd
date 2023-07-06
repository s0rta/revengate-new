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

## A container to hold the context menu
extends Control

signal closed(acted:bool)

var has_panned := false

func _unhandled_input(event):
	# dismiss on tap away, but let the pan pass through
	# FIXME: dismissing works, but pan events are not passing through
	if event.is_action_pressed("pan"):
		has_panned = false
	elif event.is_action_released("pan"):
		if not has_panned:
			accept_event()
			close(false)
	elif event is InputEventMouseButton and event.is_pressed():
		accept_event()
		close(false)
	elif event.is_action_pressed("ui_cancel"):
		accept_event()
		close(false)

func show_commands(commands, coord=null):
	# TODO: find where to show the context menu for max visibility
	for cmd in commands:
		# TODO: use CommandButton
		var button = Button.new()
		button.text = cmd.caption
		if cmd.is_action:
			button.theme_type_variation = "ActionBtn"
		button.pressed.connect(run_command.bind(cmd, coord))
		%VBox.add_child(button)
	show()
	
func run_command(cmd, coord):
	hide()
	var acted = await cmd.run(coord)
	close(acted)

func close(acted:bool=false):
	hide()
	for child in %VBox.get_children():
		child.queue_free()
	emit_signal("closed", acted)
