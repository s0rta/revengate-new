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

@onready var credits_label: RichTextLabel = %CreditsLabel

func _ready():
	var file = FileAccess.open("res://CREDITS.md", FileAccess.READ)
	if file:
		var text = file.get_as_text()

		# linkify
		var re = RegEx.create_from_string(r"(http.*)(\s)")
		text = re.sub(text, r"[url]$1[/url]$2", true)

		credits_label.text = text
