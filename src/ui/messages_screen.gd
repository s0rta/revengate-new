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

## A window to view the history of messages
class_name MessagesScreen extends ModalScreen

const MAX_MESSAGES:=500
const COLLAPSE_WINDOW = 10

var messages := []

func popup():
	trim_old_messages()
	%ListView.clear()
	var lines = Utils.collapse_strings_fmt(messages, COLLAPSE_WINDOW)
	for line in lines:
		%ListView.add_item(line)
	$EmptyLabel.visible = (%ListView.item_count == 0)
	%ListView.select(%ListView.item_count-1)
	%ListView.ensure_current_is_visible()
	super()

func trim_old_messages():
	var nb_msg = len(messages)
	var extra = max(0, nb_msg - MAX_MESSAGES)
	if extra:
		messages = messages.slice(extra)
	
func add_message(text:String, 
				level:Consts.MessageLevels, 
				tags:Array):
	messages.append(text)
	if len(messages) > MAX_MESSAGES * 2:
		trim_old_messages()

func _on_back_button_pressed():
	close(false)
