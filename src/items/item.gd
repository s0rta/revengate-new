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

## Something that can fit in someone's inventory
@icon("res://assets/dcss/urand_mage.png")
class_name Item extends Node2D

@export var char := "⚒"
@export var caption := ""
@export var consumable := false
@export var switchable := false  # can you turn this item ON and OFF?

# TODO: "spawn" sounds more like something that applies to living things...
@export var spawn_cost := 0.0
@export var ttl := -1
@export var tags:Array[String]
var depleted := false

var shrouded := false  # partially or completely obscured
var _shroud_anim = null  # only one fading going on at a time

func _ready():
	$Label.text = char
	Utils.assert_all_tags(tags)
	Utils.hide_unplaced(self)

func _to_string():
	var str = caption
	if len(str) == 0:
		str = name
	return "<Item %s>" % [str]

func _dissipate():
	## Do some cleanup, then vanish forever
	depleted = true
	if visible:
		var coord = get_cell_coord()
		await shroud()
	queue_free()

func start_new_turn():
	if depleted:
		return
	if ttl > 0:
		ttl -= 1
	if ttl == 0:
		_dissipate()

func ddump():
	print(self)
	print("  modifiers: %s" % [Utils.get_node_modifiers(self)])

func is_expired():
	return ttl == 0 or depleted

func is_unexposed():
	## Return if this item being played on a board other than the active one
	var parent = get_parent()
	if parent == null:
		return true
	elif parent is RevBoard:
		return not parent.visible
	elif parent is Actor:
		return parent.is_unexposed()

func get_board():
	var parent = get_parent()
	if parent is Actor:
		return parent.get_board()
	elif parent is RevBoard:
		return parent
	else:
		assert(false, "This item does not seem to be in play")

func get_cell_coord():
	## Return the board coord of the item or the coord of its owner if the item 
	##   is in someone's inventory.
	## Return null if the item is not yet in play.
	var parent = get_parent()
	if parent == null or parent is RevBoard:
		return RevBoard.canvas_to_board(position)
	elif parent is Actor:
		return parent.get_cell_coord()
	else:
		assert(false, "This item does not seem to be in play")

func get_short_desc():
	var desc = caption
	if len(desc) == 0:
		desc = name
	var qualifiers = []
	for tag in ["lit", "broken"]:
		if tag in tags:
			qualifiers.append(tag)
	if qualifiers:
		return "%s %s (%s)" % [$Label.text, desc, ", ".join(qualifiers)]
	else:
		return "%s %s" % [$Label.text, desc]

func place(coord, _immediate=null):
	## Place the item at the specific coordinate without animations.
	## No tests are done to see if `coord` is a suitable location.
	## _immediate: ignored.
	position = RevBoard.board_to_canvas(coord)

func should_hide(index=null):
	if not get_parent() is RevBoard:
		return true
	if index == null:
		index = get_board().make_index()
	var here = get_cell_coord()
	if self != index.top_item_at(here):
		return true
	else:
		return false

func should_shroud(index=null):
	if index == null:
		index = get_board().make_index()
	var here = get_cell_coord()
	if self == index.top_item_at(here):
		var actor = index.actor_at(here)
		if actor != null and not actor.is_dead() and not actor.is_unexposed():
			return true
	return false

func shroud(animate=true):
	Utils.shroud_node(self, animate)
		
func unshroud(animate=true):
	Utils.unshroud_node(self, animate)
	
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

func toggle():
	assert(switchable, "This item cannot be turned ON or OFF.")
	pass  # sub-classes must override this behavior
