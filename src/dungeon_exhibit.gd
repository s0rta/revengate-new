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
	if stairs.is_empty():
		print("No stairs to go down!")
	elif len(stairs) > 1:
		_show_exit_selector(old_board, stairs)
	else:
		follow_connector_at(old_board, stairs[0])

func go_higher():
	## Go closer to the entrance, vertically
	var old_board = $Dungeon.get_board()
	var stairs = old_board.get_cells_by_terrain("stairs-up")
	if stairs.is_empty():
		print("No stairs to go up!")
	elif len(stairs) > 1:
		_show_exit_selector(old_board, stairs)
	else:
		follow_connector_at(old_board, stairs[0])

func follow_connector_at(old_board:RevBoard, coord):
	var new_board = null
	var conn = old_board.get_connection(coord)
	if conn:
		new_board = conn.far_board
	else:
		# FIXME: the dungeon should do most of that
		var near_terrain = old_board.get_cell_terrain(coord)
		var new_loc = old_board.get_cell_rec_val(coord, "conn_target", "world_loc")
		new_board = $Dungeon.build_board(old_board.depth + 1, new_loc, $Dungeon.DEF_SIZE, old_board.world_loc)
		# connect the stairs together
		var far_terrain = $Dungeon.opposite_connector(near_terrain)
		var far = new_board.get_cell_by_terrain(far_terrain)
		conn = old_board.add_connection(coord, new_board, far)
		old_board.clear_cell_rec(coord, "conn_target")
		
	old_board.set_active(false)
	new_board.set_active(true)
	print("New board is active, depth: %s, loc: %s" % [new_board.depth, RevBoard.world_loc_str(new_board.world_loc)])
	print("   neighbors are: %s" % [new_board.get_neighbors_str()])

func _show_exit_selector(old_board, coords):
	var vbox = %ExitSelector/VBox 
	for child in vbox.get_children():
		child.hide()
		child.queue_free()
	for coord in coords:
		var btn = Button.new()
		btn.text = "Stairs at %s" % RevBoard.coord_str(coord)
		vbox.add_child(btn)

		btn.pressed.connect(%ExitSelector.hide)
		var switcher = follow_connector_at.bind(old_board, coord)
		btn.pressed.connect(switcher)
	%ExitSelector.show()

func _on_exit_selector_gui_input(event):
	if event is InputEventMouseButton:
		%ExitSelector.hide()
