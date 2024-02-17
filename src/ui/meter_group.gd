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

## A group of controls to display a value with a predermined range: 
## a meter bar and a text caption of the value.
extends VBoxContainer

const CRIT_PCT = 20  # as a percent of value_full

@export var value_name : String
@export var value : int
@export var value_full : int  # over-filling is possible
@export var color:Color

func _ready():
	if value_name:
		%CaptionLabel.text = value_name + ":"
	assert(value_full, "value_full not provided")
	
	var stylebox = %MeterBar.get_theme_stylebox("fill")
	stylebox.bg_color = color

func set_value(new_value):
	value = new_value
	%ValueLabel.text = "%2d" % new_value
	if value_full:
		var value_pct = 100.0 * value / value_full
		%MeterBar.value = value_pct
		if value_pct <= CRIT_PCT:
			%MeterBar.modulate = Color.RED
		elif value_pct > 100:
			%MeterBar.modulate = Color.GREEN_YELLOW
		else:
			%MeterBar.modulate = Color.WHITE
	else:
		%MeterBar.value = 0
