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

extends "res://src/ui/secondary_info_screen.gd"

@onready var credits_label: Label = find_child("CreditsLabel")

func _ready():
	var file = FileAccess.open("res://CREDITS.md", FileAccess.READ)
	if file:
		var text = file.get_as_text()
		var nb_lines = text.count("\n")
		credits_label.text = text
		var nb_vis_lines = credits_label.get_visible_line_count()
		if nb_vis_lines < nb_lines:
			var line_height = credits_label.get_line_height()
			var size = credits_label.get_size()
			var new_height = round(1.1 * nb_lines * line_height)
			credits_label.custom_minimum_size = V.i(size.x, new_height)

