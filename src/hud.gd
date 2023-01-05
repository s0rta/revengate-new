# Copyright © 2022 Yannick Gingras <ygingras@ygingras.net> and contributors

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

extends Node

var hero: Actor

func set_hero(hero_):
	hero = hero_
	hero.was_attacked.connect(refresh_hps)
	hero.moved.connect(_refresh_stair_button_enabled)
	refresh_hps()

func refresh_hps(_arg=null):
	# TODO: bold animation when dead
	$StatusBar/HPLabel.text = "%2d" % hero.health

func _refresh_stair_button_enabled(hero_coord):
	var board = find_parent("Main").get_board()
	$ButtonBar/StairsButton.disabled = not board.is_connector(hero_coord)

func _on_stairs_button_pressed():
	var event = InputEventAction.new()
	event.action = "follow-stairs"
	event.pressed = true
	Input.parse_input_event(event)
