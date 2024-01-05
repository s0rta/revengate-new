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

## Show a long narration in a modal way.
class_name StoryScreen extends ModalScreen

func show_story(title, body_path):
	%TitleLabel.text = title
	%ScrollView.get_v_scroll_bar().value = 0
	var body = FileAccess.open(body_path, FileAccess.READ).get_as_text()
	%StoryLabel.text = body
	popup()

func _on_ok_button_button_up():
	close(false)
