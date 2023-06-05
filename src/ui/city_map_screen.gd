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

## Map of Lyon with the hero's approximate location highlighted
extends Control

const GRIP_PIXELS = 64  # locations grid, not to be consused with the RevBoard grid
const MAP_PATH = "res://assets/lyon-map-1855.png"
const LABEL_FMT = "[center][img=%dx%d]%s[/img][/center]"
const TIP_POS = Vector2(56.0, 32.0)  # where the tip of the pointer is inside the label

var map_size: Vector2i

func _ready():
	%MapLabel.text = LABEL_FMT % [size.x, size.y, MAP_PATH]
	
func _input(event):
	# We are not truly modal, so we prevent keys from sending action to the game board
	# while visible.
	if visible and event is InputEventKey:
		accept_event()

func popup(world_loc=null):
	show()
	highlight_loc(world_loc)

func highlight_loc(world_loc):
	## Display on pointer in the general area of `world_loc`
	if world_loc == null or world_loc == Consts.LOC_INVALID:
		%PointerLabel.hide()
		return

	if map_size == null or map_size == Vector2i.ZERO:
		var img = load(MAP_PATH)
		map_size = img.get_size()
	var nb_cells = Vector2(map_size / GRIP_PIXELS)
	var pixel_step = size / nb_cells	
	var new_pos = pixel_step * Vector2(world_loc.x+0.5, world_loc.y+0.5) - TIP_POS
	%PointerLabel.position = new_pos
	%PointerLabel.show()

func _on_back_button_pressed():
	hide()
