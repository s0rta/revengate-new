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

## something that can fit in someone's inventory
class_name Item extends Node2D

const FADE_DURATION := .15
const FADE_MODULATE := Color(.7, .7, .7, 0.0)
const VIS_MODULATE := Color.WHITE

@export var char := "⚒"
@export var caption := ""
@export var consumable := false

# TODO: "spawn" sounds more like something that applies to living things...
@export var spawn_cost := 0.0


func _ready():
	$Label.text = char

func _to_string():
	var str = caption
	if len(str) == 0:
		str = name
	return "<Item %s>" % [str]

func ddump():
	print(self)
	print("  modifiers: %s" % [Utils.get_node_modifiers(self)])

func get_cell_coord():
	## Return the board position of the item or null if the item is not on a board.
	## This can happen for example if the item is in an actor's inventory.

	# FIXME: detect when we are not on a board
	return RevBoard.canvas_to_board(position)

func get_short_desc():
	var desc = caption
	if len(desc) == 0:
		desc = name
	return "%s %s" % [$Label.text, desc]

func place(coord, _immediate=null):
	## Place the item at the specific coordinate without animations.
	## No tests are done to see if `coord` is a suitable location.
	## _immediate: ignored.
	position = RevBoard.board_to_canvas(coord)

func fade_out():
	## Slowly hide the item with an animation. 
	var anim = get_tree().create_tween()
	anim.tween_property(self, "modulate", FADE_MODULATE, FADE_DURATION)
	await anim.finished
	visible = false
	
func fade_in():
	## Slowly display the item with an animation. 
	modulate = FADE_MODULATE
	visible = true
	var anim = get_tree().create_tween()
	anim.tween_property(self, "modulate", VIS_MODULATE, FADE_DURATION)

func flash_in():
	## Istantly display the item without animation. 
	## The inverse of this operation is the built-in CanvasItem.hide()
	modulate = VIS_MODULATE
	show()

func toggle_visible(animate:=true):
	if visible:
		if animate:
			fade_out()
		else:
			hide()
	else:
		if animate:
			fade_in()
		else:
			flash_in()
	
func is_on_board():
	## Return `true` if the item is laying somewhere on the board, `false` it belongs to 
	## an actor inventory or inaccessible for some other reason.
	return get_parent() is RevBoard
	
func activate_on_actor(actor):
	## activate the item on actor
	for node in get_children():
		if node is Effect:
			node.apply(actor)
	if consumable:
		queue_free()

func activate_on_coord(coord):
	assert(false, "not implemented")
