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
@onready var loot_button = find_child("LootButton")
@onready var stairs_button = find_child("StairsButton")

func set_hero(hero_):
	hero = hero_
	hero.was_attacked.connect(refresh_hps)
	hero.moved.connect(refresh_buttons_vis)
	refresh_hps()
	refresh_buttons_vis(null, hero.get_cell_coord())

func refresh_hps(_arg=null):
	# TODO: bold animation when dead
	$StatusBar/HPLabel.text = "%2d" % hero.health

func update_states_at(hero_coord):
	## Refresh internal states by taking into account a recent change at `hero_coord`
	var board = hero.get_board()
	stairs_button.visible = board.is_connector(hero_coord)
	var index = board.make_index()
	loot_button.visible = null != index.top_item_at(hero_coord)

func refresh_buttons_vis(_old_coord, hero_coord):
	## update the visibility of some action button depending on where the hero is standing
	update_states_at(hero_coord)

func _on_stairs_button_pressed():
	var event = InputEventAction.new()
	event.action = "follow-stairs"
	event.pressed = true
	Input.parse_input_event(event)
