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

## A standalone scene to see the levels that a dungeon can generate.
class_name DungeonExhibit extends Node2D

func _unhandled_input(event):
	if Input.is_action_just_pressed("up"):
		go_higher()
	elif Input.is_action_just_pressed("down"):
		go_deeper()
	elif Input.is_action_just_pressed("right"):
		print("Right")
	elif Input.is_action_just_pressed("left"):
		print("Left")
	elif Input.is_action_just_pressed("refresh"):
		refresh()
	$/root.set_input_as_handled()

func refresh():
	var board = $Dungeon.get_board()
	if board:
		$Dungeon.regen(board)
	else:
		print("No active board to refresh.")

func go_deeper():
	## Go further into the dungeon vertically
	var old_board = $Dungeon.get_board()
	var stairs = old_board.get_cells_by_terrain("stairs-down")
	assert(len(stairs) == 1, "Multi-stairs and dead ends are not supported yet.")
	var coord = stairs[0]
	var new_board = null
	var conn = old_board.get_connection(coord)
	if conn:
		new_board = conn.far_board
	else:
		new_board = $Dungeon.build_board(old_board.depth + 1)
		# connect the stairs together
		var far = new_board.get_cell_by_terrain("stairs-up")
		# TODO: add_connection() should return the new record
		old_board.add_connection(coord, new_board, far)		
		conn = old_board.get_connection(coord)
		
	old_board.set_active(false)
	new_board.set_active(true)

func go_higher():
	## Go closer to the entrance, vertically
	var old_board = $Dungeon.get_board()
	var stairs = old_board.get_cells_by_terrain("stairs-up")
	assert(len(stairs) == 1, "Multi-stairs and dead ends are not supported yet.")
	var conn = old_board.get_connection(stairs[0])
	if conn:
		old_board.set_active(false)
		conn.far_board.set_active(true)
