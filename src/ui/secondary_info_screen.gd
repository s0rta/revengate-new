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

## Common script used by all the trivial info screens accessed from the 
## start screen.
extends Node

func _on_back_button_pressed():
	show_main_screen()

func show_main_screen():
	get_tree().change_scene_to_file("res://src/ui/start_screen.tscn")
	
func start_new_game():
	get_tree().change_scene_to_file("res://src/main.tscn")

func follow_link(url:String):
	assert(url.begins_with("http"), "'%s' does not look like a url" % [url])
	OS.shell_open(url)
