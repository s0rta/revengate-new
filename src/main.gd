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

func test_change_board():
	var new_board = $Board.duplicate()
	var builder = BoardBuilder.new(new_board)
	builder.gen_level()

	var bbox = null
	for thing in [$Hero, $Monster, $Monster2]:
		print("moving %s somewhere else" % [thing])
		builder.place(thing, false, null, false, bbox)

	var old_board = $Board
	old_board.replace_by(new_board)
	old_board.queue_free()

func _input(_event):
	if Input.is_action_just_pressed("test"):
		test_change_board()

