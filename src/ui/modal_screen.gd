# Copyright © 2024 Yannick Gingras <ygingras@ygingras.net> and contributors

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

class_name ModalScreen extends Control

signal closed(acted:bool)

func _input(event):
	
	# DEBUG
	Utils.ddump_event(event, self, "_input")
	
	# FIXME: this logic should go in _unhandled_input() or _gui_input() once we have all the other screens normalized
	if visible and event.is_action_pressed("ui_cancel"):
		accept_event()
		close()
	elif visible and event is InputEventKey:
		# We have to implement the modal behavior ourselves, so we prevent keys from sending action
		# to the game board while visible.
		accept_event()

func popup():
	show()

func close(has_acted:=false):
	## Hide the screen, emit `closed` with whether the Hero has acted while the 
	## ModalScreen was visible. 
	## SubClasses can override this method to have fancier logic on what counts as an action.
	hide()
	emit_signal("closed", has_acted)
