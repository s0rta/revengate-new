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

## Something that you can perceive as you go around the dungeon, but that you can't pick up.
@icon("res://assets/dcss/torch_1.png")
class_name Vibe extends Node2D

@export var char := ""
@export var caption := ""
@export var spawn_cost := 0.0
@export var tags:Array[String]

func _ready():
	$Label.text = char
	Utils.assert_all_tags(tags)
	Utils.hide_unplaced(self)

func get_cell_coord():
	## Return the board coord of the vibe or null if the vibe has not been placed.
	var parent = get_parent()
	if parent is RevBoard:
		return RevBoard.canvas_to_board(position)
	else:
		return null

func place(coord, _immediate=null):
	## Place the vibe at the specific coordinate without animations.
	## No tests are done to see if `coord` is a suitable location.
	## _immediate: ignored.
	position = RevBoard.board_to_canvas(coord)

func activate():
	## The Vibe just got noticed, so make that obvious
	if caption.is_empty():
		return  # turns out this vibe is really subtle...
	Tender.hud.add_message("You notice %s" % caption)
	
