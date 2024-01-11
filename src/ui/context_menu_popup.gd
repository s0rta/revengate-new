# Copyright © 2023-2024 Yannick Gingras <ygingras@ygingras.net> and contributors

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
extends ModalScreen

func _gui_input(event):
	if event is InputEventMouseButton and event.is_pressed():
		# Dismiss on tap away. Buttons are called before us, so if get the 
		# button event, it's because it was outside of any buttons.
		accept_event()
		close(false)

func show_commands(commands, coord=null):
	# TODO: find where to show the context menu for max visibility
	for cmd in commands:
		# TODO: use CommandButton
		var button = Button.new()
		button.text = cmd.get_caption()
		if cmd.is_action:
			button.theme_type_variation = "ActionBtn"
		button.pressed.connect(run_command.bind(cmd, coord))
		%VBox.add_child(button)
	show()
	
func run_command(cmd, coord):
	hide()
	var acted = await cmd.run(coord)
	close(acted)

func close(has_acted:bool=false):
	for child in %VBox.get_children():
		child.queue_free()
	super(has_acted)
