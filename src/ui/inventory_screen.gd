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

class_name InventoryScreen extends ModalScreen

signal inventory_changed

enum Cols {
	DESC,
	EQUIP,
	USE,
	DROP 
}

var actor = null
# Did the player do something that counts as a turn action while the screen was open?
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
	
	for row in %AllItems.find_children("", "InventoryRow", false, false):
		row.remove()
	
	for item in items:
		var row = _make_row(item)	
		%AllItems.add_child(row)
		_connect_row(row)
		row.show()
	
func _make_row(item):
	## Create a new Item row
	## The caller is responsible for adding the row in %AllItems
	var row = %ItemRecordTemplate.duplicate()
	row.item = item
	return row

func _connect_row(row):
	## Connect all the row button to actions on this screen.
	## Can only be called after the row has been added to the scene.
	row.equip_button.button_up.connect(equip_item.bind(row))
	row.consume_button.button_up.connect(consume_item.bind(row))
	row.activate_button.button_up.connect(switch_item.bind(row))
	row.toss_button.button_up.connect(toss_item.bind(row))
	row.drop_button.button_up.connect(drop_item.bind(row))

func reset_empty_label_vis():
	if not actor:
		$EmptyLabel.visible = false
	else:
		var items = actor.get_items()
		$EmptyLabel.visible = not items.size()

func reset_equip_state():
	for row in %AllItems.find_children("", "InventoryRow", false, false):
		if not row.visible or not row.item:
			continue
		var item = row.item
		var is_equipped = item.get("is_equipped")
		if is_equipped != null:
			row.equip_button.disabled = is_equipped

func _on_back_button_pressed():
	close()

func equip_item(row:InventoryRow):
	acted = true
	var item = row.item
	actor.equip_item(item)
	row.refresh()
	reset_equip_state()

func toss_item(row:InventoryRow):
	var item = row.item
	if item is ItemGrouping:
		item = item.top()
	var radius = actor.get_throw_range() + 1
	var board = actor.get_board()
	var coords = board.visible_coords(Tender.hero, radius)
	board.paint_cells(coords, "highlight-info", board.LAYER_HIGHLIGHTS)

	if item is Weapon:
		# highlight the effective range of ranged weapons
		var item_range = actor.get_eff_weapon_range(item)
		if item_range and item_range > 1:
			var effective_coords = board.visible_coords(Tender.hero, item_range+1)
			board.paint_cells(effective_coords, "highlight-warning", board.LAYER_HIGHLIGHTS)	
			coords += effective_coords
	hide()

	var surveyor = Tender.hud.get_gesture_surveyor()
	var msg = "Toss %s where?" % [item.get_short_desc()]
	var res = await surveyor.start_capture_coord(msg, coords)
	if res.success:
		acted = true
		res.coord
		assert(res.coord in coords)
		var index = actor.get_board().make_index()
		var foe = index.actor_at(res.coord)
		if item is Weapon and foe:
			actor.strike(foe, item, true)
		else:
			actor.drop_item(item, res.coord)
		if Utils.has_tags(item, ["fragile"]):
			item.wreck()
		close(acted)
	else:
		actor.get_board().clear_highlights()
		show()

func drop_item(row:InventoryRow):
	acted = true
	var item = row.item
	if item is ItemGrouping:
		var grouping = item
		item = grouping.pop()
		if grouping.is_empty():
			row.remove()
		else:
			if item.get("is_equipped") and not grouping.is_empty():
				# equip the next similar item on the stack
				grouping.is_equipped = true
			row.refresh()
	else:
		row.remove()

	actor.drop_item(item)
	inventory_changed.emit()

func consume_item(row:InventoryRow):
	acted = true
	var item = row.item
	assert(item.consumable)
	if item is ItemGrouping:
		var grouping = item
		item = grouping.pop()
		if grouping.is_empty():
			row.remove()
		else:
			row.refresh()
	else:
		row.remove()
	actor.consume_item(item)
			
func switch_item(row:InventoryRow):
	acted = true
	var item = row.item
	assert(item.switchable)
	if item is ItemGrouping:
		var grouping = item
		item = grouping.pop()
		item.toggle()
		var new_row = _make_row(item)
		row.add_sibling(new_row)
		_connect_row(new_row)
		new_row.show()
		if grouping.is_empty():
			row.remove()
		else:
			row.refresh()
	else:
		item.toggle()
		row.refresh()
	
func _show_item_details(item):
	$ItemDetailsScreen.show_item(item)	
