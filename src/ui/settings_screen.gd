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

extends "res://src/ui/secondary_info_screen.gd"

var DD_ITEM_TO_TSIZE = Consts.TextSizes.values().slice(1)

@onready var tabulator:Tabulator = Tabulator.load()

func _ready():
	%CheatsCheck.button_pressed = tabulator.allow_cheats
	%ShadersCheck.button_pressed = tabulator.enable_shaders
	if tabulator.text_size != Consts.TextSizes.UNSET:
		%TextSizeDropdown.selected = DD_ITEM_TO_TSIZE.find(tabulator.text_size)

func _on_cheats_check_toggled(toggled_on):
	tabulator.allow_cheats = toggled_on
	tabulator.save()

func _on_shaders_check_toggled(toggled_on):
	tabulator.enable_shaders = toggled_on
	tabulator.save()

func _on_text_size_dropdown_item_selected(index):
	var size = DD_ITEM_TO_TSIZE[index]
	tabulator.text_size = DD_ITEM_TO_TSIZE[index]
	tabulator.save()
	UIUtils.resize_text_controls(size)
