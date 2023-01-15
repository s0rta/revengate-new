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

class_name InventoryScreen

signal inventory_changed

@onready var tree_view:Tree = find_child("Tree")
var button_img = load("res://src/ui/drop_btn.png")
var actor = null

func _ready():
	inventory_changed.connect(reset_empty_label_vis)

func _input(event):
	# We are not truly modal, so we prevent keys from sending action to the game board
	# while visible.
	if visible and event is InputEventKey:
		accept_event()
	tree_view.set_column_title(0, "description")
	tree_view.set_column_title(1, "action")

func fill_actor_items(actor_:Actor):
	actor = actor_
	tree_view.clear()
	var root = tree_view.create_item()
	var items = actor.get_items()
	$EmptyLabel.visible = not items.size()
	for item in items:
		var row = tree_view.create_item(root)
		row.set_metadata (0, item)
		row.set_text(0, item.name)
		row.add_button(0, button_img)

func reset_empty_label_vis():
	if not actor:
		$EmptyLabel.visible = false
	else:
		var items = actor.get_items()
		$EmptyLabel.visible = not items.size()

func _on_back_button_pressed():
	# FIXME: turn handling when we come back from that screen
	hide()
	
func _on_tree_button_clicked(row, column, id, mouse_button_index):
	var item = row.get_metadata(0)
	row.set_button_disabled(column, id, true)
	row.free()
	actor.drop_item(item)
	emit_signal("inventory_changed")
