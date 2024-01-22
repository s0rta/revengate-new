# Copyright © 2023-2024 Yannick Gingras <ygingras@ygingras.net> and contributors

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

# TODO: Hide row when last item in stack is used or dropped
# TODO: Update label when we use an item from a non empty stack
# TODO: Duplicate rows when we toggle something that was part of a stack

class_name InventoryScreen extends ModalScreen

signal inventory_changed

enum Cols {
	DESC,
	EQUIP,
	USE,
	DROP 
}

var actor = null
# Did the player did something that counts as a turn action while the screen was open?
var acted := false 


func _ready():
	inventory_changed.connect(reset_empty_label_vis)

func popup():
	acted = false
	super()

func close(close_is_action:=false):
	super(close_is_action or acted)

func fill_actor_items(actor_:Actor):
	actor = actor_
	var items = actor.get_items()
	$EmptyLabel.visible = not items.size()
	
	for child in %AllItems.find_children("", "InventoryRow", false, false):
		child.hide()
		child.queue_free()
	
	for item in items:
		var row = %ItemRecordTemplate.duplicate()
		
		%AllItems.add_child(row)
		row.item = item
		
		var label = row.label
		label.text = item.get_short_desc()
		
		var equip_button = row.equip_button
		var is_equipped = item.get("is_equipped")
		if is_equipped != null:
			equip_button.disabled = is_equipped
			equip_button.button_up.connect(equip_item.bind(item))
		else:
			equip_button.hide()
			
		var consume_button = row.consume_button
		if not item.consumable:
			consume_button.hide()
		else:
			consume_button.button_up.connect(consume_item.bind(item))
			
		var drop_button = row.drop_button
		drop_button.button_up.connect(drop_item.bind(item))
		

		row.show()
	
	#tree_view.clear()
	#var root = tree_view.create_item()
	#
	#
	#for item in items:
		#var row = _make_from_item(item, root)

func reset_empty_label_vis():
	if not actor:
		$EmptyLabel.visible = false
	else:
		var items = actor.get_items()
		$EmptyLabel.visible = not items.size()

func reset_buttons_vis():
	for row in %AllItems.find_children("", "InventoryRow", false, false):
		if not row.visible:
			continue
		var item = row.item
		var is_equipped = item.get("is_equipped")
		if is_equipped != null:
			row.equip_button.disabled = is_equipped

func _on_back_button_pressed():
	close()

func _refresh_row(row, item):
	row.set_text(Cols.DESC, item.get_short_desc())

	var use_disabled = not (item.consumable or item.switchable)
	row.set_button_disabled(Cols.USE, 0, use_disabled)

	var drop_disabled = not (item is ItemGrouping and not item.is_empty())
	row.set_button_disabled(Cols.DROP, 0, drop_disabled)

func drop_item(item):
	if item is ItemGrouping:
		var grouping = item
		item = grouping.pop()
		if item.get("is_equipped") and not grouping.is_empty():
			grouping.is_equipped = true

	actor.drop_item(item)

func consume_item(item):
	if item.consumable:
		if item is ItemGrouping:
			var grouping = item
			item = grouping.pop()
		actor.consume_item(item)
	
			
func switch_item(item):
	if item.switchable:
		item.toggle()
		if item is ItemGrouping:
			var grouping = item
			var top_item = grouping.pop()

func _old_use_item(row, item):
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
		if item is ItemGrouping:
			var grouping = item
			var top_item = grouping.pop()
			if grouping.is_empty():
				row.free()
			else:
				_refresh_row(row, item)
		else:
			_refresh_row(row, item)



func _on_tree_item_selected():
	var row = %Tree.get_selected()
	var item = row.get_metadata(0)
	$ItemDetailsScreen.show_item(item)
	%Tree.deselect_all()
	
func _show_item_details(item):
	$ItemDetailsScreen.show_item(item)	

func equip_item(item):
	actor.equip_item(item)
	reset_buttons_vis()
	

	
