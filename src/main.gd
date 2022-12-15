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

extends Node2D

func get_board():
	## Return the current active board
	var current = null
	for node in get_children():
		if node is RevBoard and node.visible:
			current = node
	if current:
		return current
	else:
		return $"Board"

func test_change_board():
	var tree = load("res://src/rev_board.tscn") as PackedScene
	var new_board = tree.instantiate() as RevBoard
	var builder = BoardBuilder.new(new_board)
	builder.gen_level()
	
	var index = new_board.make_index()
	var bbox = null
	for thing in [$Hero, $Monster, $Monster2]:
		var old_coord = thing.get_cell_coord()
		var new_coord = builder.place(thing, false, null, true, bbox, index)
		index.add_actor(thing)

	var old_board = get_board()
	old_board.add_sibling(new_board)
	old_board.visible = false

func _input(_event):
	if Input.is_action_just_pressed("test"):
		test_change_board()
