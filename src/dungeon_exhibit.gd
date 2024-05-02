# Copyright © 2023–2024 Yannick Gingras <ygingras@ygingras.net> and contributors

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

var board: RevBoard  # the active board

func _ready():
	for dungeon in find_children("", "Dungeon", true, false):
		if dungeon.has_starting_board():
			board = dungeon.finalize_static_board()
			board.set_active(true)
	assert(board != null, "Could not find a starting board!")

func _switch_board(new_board:RevBoard):
	## set `new_board` as the active board
	board.set_active(false)
	new_board.set_active(true)
	board = new_board
	_scale_to_fit_board()

func _unhandled_input(event):
	if Input.is_action_just_pressed("up"):
		go_higher()
	elif Input.is_action_just_pressed("down"):
		go_lower()
	elif Input.is_action_just_pressed("right"):
		go_deeper()
	elif Input.is_action_just_pressed("left"):
		go_shallower()
	elif Input.is_action_just_pressed("refresh"):
		refresh()
	$/root.set_input_as_handled()

func _get_dungeon(board:RevBoard):
	var parent = board.get_parent()
	if parent is Dungeon:
		return parent
	return null

func _scale_to_fit_board():
	var viewport = get_viewport()
	var px_size:Vector2 = board.get_used_rect().size * board.TILE_SIZE
	var ratios = Vector2(viewport.size) / px_size
	viewport.get_camera_2d().zoom = Vector2.ONE * min(ratios.x, ratios.y)

func refresh():
	## rebuild the board at the current world loc, preserving cross-board connections
	if board:
		var dungeon = _get_dungeon(board)
		if dungeon:
			board = dungeon.regen(board)
	else:
		print("No active board to refresh.")

func _progress_on_depth(depth_pred):
	## Pick an exit that match `depth_pred`
	## Return if at least one exit could be found
	var old_board = board
	var coords = []
	for coord in old_board.get_connectors():
		var depth = old_board.get_cell_rec_val(coord, "conn_target", "depth")
		if depth == null:
			var conn = old_board.get_connection(coord)
			var far_board = old_board.get_dungeon().get_board_by_id(conn.far_board_id)
			depth = far_board.depth
		if depth_pred.call(depth):
			coords.append(coord)
	if coords.is_empty():
		return false
	else:
		if len(coords) > 1:
			_show_exit_selector(old_board, coords)
		else:
			follow_connector_at(old_board, coords[0])
	return true

func _progress_on_loc(loc_pred):
	## Pick an exit that match `loc_pred`
	## Return if at least one exit could be found
	var old_board = board
	var coords = []
	for coord in old_board.get_connectors():
		var loc = old_board.get_cell_rec_val(coord, "conn_target", "world_loc")
		if loc == null:
			var conn = old_board.get_connection(coord) 
			loc = conn.far_loc
		if loc_pred.call(loc):
			coords.append(coord)
	if coords.is_empty():
		return false
	else:
		if len(coords) > 1:
			_show_exit_selector(old_board, coords)
		else:
			follow_connector_at(old_board, coords[0])
	return true
	
func go_deeper():
	## Go further into the dungeon topologically
	var old_board = board
	var deeper = func(depth):
		return depth > old_board.depth
	if not _progress_on_depth(deeper):
		print("No exits to go deeper!")

func go_shallower():
	## Go back towards the entrance of the dungeon 
	var old_board = board
	var shallower = func(depth):
		return depth < old_board.depth
	if not _progress_on_depth(shallower):
		print("No exits to go back towards the entrance of the dungeon!")

func go_higher():
	## Go closer to the surface
	var old_board = board
	var higher = func(loc):
		return loc.z > old_board.world_loc.z
	if not _progress_on_loc(higher):
		print("No exits to go back towards the surface!")

func go_lower():
	## Go away from the surface
	var old_board = board
	var lower = func(loc):
		return loc.z < old_board.world_loc.z
	if not _progress_on_loc(lower):
		print("No exits to go lower!")

func follow_connector_at(old_board:RevBoard, coord):
	var new_board:RevBoard
	var conn = old_board.get_connection(coord)
	if conn:
		new_board = old_board.get_dungeon().get_board_by_id(conn.far_board_id)
	else:
		var conn_target = old_board.get_cell_rec(coord, "conn_target")
		var old_dungeon = old_board.get_dungeon() 
		new_board = old_dungeon.new_board_for_target(old_board, conn_target)
		
		# connect the outgoing connecter with the incomming one
		conn = old_board.add_connection(coord, new_board)
		
	_switch_board(new_board)
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
		
