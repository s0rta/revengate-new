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

extends Control

# Events propagate as follow:
# 1) _input() in reverse depth for all controls
# 2) _gui_input() for the control where the click was
# 3) _unhandled_input() in reverse depth for all controls

# disabled controls still get _gui_input() and _unhandled_input()
# invisible controls pass _gui_input() to their parent, they still receive _unhandled_input()
# the SubViewPortCont receives _gui_input()
# the SubViewPortCont is the last one to see keys in _unhandled_input()

# Both Viewport.set_input_as_handled() and Control.accept_event() immediately stop the propagation 
# of an event. They can be called from any of the *_input() methods. Accepting the event in 
# _gui_input() will stop the built-in behavior of the control.
# z_index changes the drawing, not the order of input handling

# When mouse emulation is active, each screen tap will trigger both an InputEventMouseButton and
# an InputEventScreenTouch, in that order. The first one completes the whole propagation as described
# above before the second one fires. Accepting the first one does not prevents the second one 
# from firing. Release events are in the same order (mouse before touch).

func print_event(event, meth_name):
	Utils.ddump_event(event, self, meth_name)

func _input(event):
	print_event(event, "_input")
	
func _gui_input(event):
	print_event(event, "_gui_input")

func _unhandled_input(event):
	print_event(event, "_unhandled_input")
