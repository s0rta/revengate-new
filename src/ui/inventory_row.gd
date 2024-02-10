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

class_name InventoryRow extends MarginContainer

signal item_details_requested(item)

var item 
var label
@onready var desc_button = find_child("DescButton", true, false)
@onready var equip_button = find_child("EquipButton", true, false)
@onready var consume_button  = find_child("ConsumeButton", true, false)
@onready var activate_button  = find_child("ActivateButton", true, false)
@onready var toss_button  = find_child("TossButton", true, false)
@onready var drop_button  = find_child("DropButton", true, false)

func _ready():
	# this is disable for now, will need more work before the label feels
	# good as the tap zone for the items detail screen
	label = find_child("Label", true, false)
	label.gui_input.connect(show_detail)
	if item:
		refresh()

func show_detail(event):
	if Utils.event_is_tap_or_left(event) and not event.pressed:
		item_details_requested.emit(item)

func remove():
	hide()
	queue_free()

func refresh():
	label.text = item.get_short_desc()
	var is_equipped = item.get("is_equipped")
	if is_equipped != null:
		equip_button.disabled = is_equipped
	else:
		equip_button.hide()
		
	consume_button.visible = item.consumable
	activate_button.visible = item.switchable
