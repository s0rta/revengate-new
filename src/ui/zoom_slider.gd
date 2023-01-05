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

extends VSlider


func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == 1 and not event.pressed:
		# hack: sometimes the signal implicitely emited on-press does not result in a 
		#   viewport resize, so we re-emit on release.
		#   This wil go away when we replace the zoom slider with pinch gestures.
		emit_signal("value_changed", value)

func _unhandled_input(event):
	if event.is_action_pressed("zoom-in"):
		value /= 1.05
	elif event.is_action_pressed("zoom-out"):
		value *= 1.05

	# consume both press and release
	if event.is_action("zoom-in") or event.is_action("zoom-out"):
		accept_event()
