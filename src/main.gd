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

# The hero moved to a different level, the UI and turn logic are affected and must be notified
signal board_changed  

var hero: Actor

func _ready():
	# FIXME: the original board should be able to re-index it's content
	$Board._append_terrain_cells([V.i(23, 2)], "stairs-down")
	hero = $Board/Hero

func get_board():
	## Return the current active board
	var current = null
	for node in get_children():
		if node is RevBoard and node.visible:
			current = node
	if current:
		return current
	else:
		return $Board

func switch_board_at(coord):
	## Flip the active board with the far side of the connector at `coord`, 
	## move the Hero to the new active board.
	## If the destination does not exist yet, create and link it with the current board.
	var old_board = get_board()
	assert(old_board.is_connector(coord), "can only switch board at a connector cell")
	var new_board = null
	var conn = old_board.get_connection(coord)
	if conn:
		new_board = conn.far_board
	else:
		new_board = make_board()
		# connect the stairs together
		var far = new_board.get_cell_by_terrain("stairs-up")
		# TODO: add should return the new record
		old_board.add_connection(coord, new_board, far)
		
		conn = old_board.get_connection(coord)
		
	old_board.set_active(false)
	new_board.set_active(true)
	var builder = BoardBuilder.new(new_board)
	var index = new_board.make_index()
	builder.place(hero, true, conn.far_coord, true, null, index)
	
	# TODO: this is not always true, a fall back might kick in if the 
	# stairs are occupied
	assert(hero.get_cell_coord() == conn.far_coord)
	
	emit_signal("board_changed")
	print("switched board by following connector at %s, dest is %s:%s" % [coord, new_board.name, conn.far_coord])


func make_board():
	## Return a brand new fully initiallized unconnected RevBoard
	var scene = load("res://src/rev_board.tscn") as PackedScene
	var new_board = scene.instantiate() as RevBoard
	add_child(new_board)
	var builder = BoardBuilder.new(new_board)
	builder.gen_level()
	
	var index = new_board.make_index()
	# TODO: monsters on a new board should be parametrized		
	for char in "rkc":
		var monster = make_monster(new_board, char)
		builder.place(monster, false, null, true, null, index)
	
	return new_board
		
func inspect_tile():
	var coord = $Hero.get_cell_coord()
	var data = (get_board() as RevBoard).get_cell_tile_data(0, coord)
	print("Data here is %s" % [[var_to_str(data), data.get_custom_data
("is_connector")]])

func make_monster(parent, char: String):
	var tree = load("res://src/combat/monster.tscn") as PackedScene
	var monster = tree.instantiate()
	monster.get_node("Label").text = char
	parent.add_child(monster)
	return monster

func _input(_event):
	if Input.is_action_just_pressed("test-2"):
		inspect_tile()
	elif Input.is_action_just_pressed("test"):
		print("Testing...")
