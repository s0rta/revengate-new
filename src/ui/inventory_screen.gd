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

class_name InventoryScreen extends Control

signal inventory_changed
signal closed(acted:bool)

enum Cols {
	DESC,
	EQUIP,
	USE,
	DROP 
}

@onready var tree_view:Tree = find_child("Tree", true)
var equip_button_img = load("res://src/ui/equip_btn.png")
var drop_button_img = load("res://src/ui/drop_btn.png")
var use_button_img = load("res://src/ui/use_btn.png")
var actor = null
# Did the player did something that counts as a turn action while the screen was open?
var acted := false  

func _ready():
	inventory_changed.connect(reset_empty_label_vis)
	tree_view.set_column_expand_ratio(Cols.DESC, 4)
	tree_view.set_column_expand(Cols.DESC, true)
	for i in range(1, tree_view.columns):
		tree_view.set_column_expand(i, false)

func _input(event):
	# We are not truly modal, so we prevent keys from sending action to the game board
	# while visible.
	if visible and event is InputEventKey:
		accept_event()

func popup():
	acted = false
	show()

func close():
	hide()
	emit_signal("closed", acted) 

func fill_actor_items(actor_:Actor):
	actor = actor_
	tree_view.clear()
	var root = tree_view.create_item()
	var items = actor.get_items()
	$EmptyLabel.visible = not items.size()
	for item in items:
		var row = tree_view.create_item(root)
		row.set_metadata(Cols.DESC, item)
		row.set_text(Cols.DESC, item.get_short_desc())
		if item.get("is_equipped") != null:
			row.add_button(Cols.EQUIP, equip_button_img)
			if item.is_equipped:
				row.set_button_disabled(Cols.EQUIP, 0, true)
		if item.consumable or item.switchable:
			row.add_button(Cols.USE, use_button_img)
		row.add_button(Cols.DROP, drop_button_img)

func reset_empty_label_vis():
	if not actor:
		$EmptyLabel.visible = false
	else:
		var items = actor.get_items()
		$EmptyLabel.visible = not items.size()

func reset_buttons_vis():
	for row in tree_view.get_root().get_children():
		var item = row.get_metadata(0)
		if item.get("is_equipped") != null:
			row.set_button_disabled(Cols.EQUIP, 0, item.is_equipped)

func unequip_all():
	for row in tree_view.get_root().get_children():
		var item = row.get_metadata(0)
		if item.get("is_equipped") != null:
			item.is_equipped = false	

func _on_back_button_pressed():
	close()

func _refresh_row(row, item):
	row.set_text(Cols.DESC, item.get_short_desc())

	var use_disabled = not (item.consumable or item.switchable)
	row.set_button_disabled(Cols.USE, 0, use_disabled)

	var drop_disabled = not (item is ItemGrouping and not item.is_empty())
	row.set_button_disabled(Cols.DROP, 0, drop_disabled)

func _drop_item(row, item):
	if item is ItemGrouping:
		var grouping = item
		item = grouping.pop()
		if grouping.is_empty():
			row.free()
		else:
			if item.get("is_equipped"):
				grouping.is_equipped = true
			_refresh_row(row, grouping)
	else:
		row.free()
	actor.drop_item(item)

func _use_item(row, item):
	if item.consumable:
		if item is ItemGrouping:
			var grouping = item
			item = grouping.pop()
			if grouping.is_empty():
				row.free()
			else:
				_refresh_row(row, grouping)
		else:
			row.free()
		actor.consume_item(item)
	elif item.switchable:
		item.toggle()
		_refresh_row(row, item)
	
func _on_tree_button_clicked(row, column, id, mouse_button_index):
	var item = row.get_metadata(0)
	row.set_button_disabled(column, id, true)
	if column == Cols.DROP:
		_drop_item(row, item)
	elif column == Cols.EQUIP:
		unequip_all()
		item.is_equipped = true
		reset_buttons_vis()
	elif column == Cols.USE:
		_use_item(row, item)
	acted = true
	emit_signal("inventory_changed")
