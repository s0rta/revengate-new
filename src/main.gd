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

@onready var hero:Actor = find_child("Hero")
@onready var hud = $HUD
@onready var boards_cont: Node = find_child("Board").get_parent()

func _ready():
	# FIXME: the original board should be able to re-index it's content
	var board = find_child("Board")
	assert(board, "Can't find the first game board")
	board._append_terrain_cells([V.i(23, 2)], "stairs-down")
	hud.set_hero(hero)
	hero.died.connect(conclude_game)
	board_changed.connect($TurnQueue.invalidate_turn)
	board_changed.connect(center_on_hero)
	await $TurnQueue.run()


func get_board():
	## Return the current active board
	var current = null
	assert(boards_cont, "Board container must be initialized")
	for node in boards_cont.get_children():
		if node is RevBoard and node.visible:
			current = node
	if current:
		return current
	else:
		return find_child("Board")

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
		new_board = make_board(old_board.depth + 1)
		# connect the stairs together
		var far = new_board.get_cell_by_terrain("stairs-up")
		# TODO: add_connection() should return the new record
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


func make_board(depth):
	## Return a brand new fully initiallized unconnected RevBoard
	var scene = load("res://src/rev_board.tscn") as PackedScene
	var new_board = scene.instantiate() as RevBoard
	new_board.depth = depth
	boards_cont.add_child(new_board)
	var builder = BoardBuilder.new(new_board)
	builder.gen_level()
	
	var index = new_board.make_index()
	
	# items
	var prev_coord = null
	for char in "🍹🥃🏖️🪔🛡️".split():
		var tree = load("res://src/item.tscn") as PackedScene
		var item = tree.instantiate()
		item.char = char
		prev_coord = builder.place(item, false, prev_coord, true, null, index)
	
	# monsters
	var nb_monsters = max(0, depth-2)
	for i in range(nb_monsters):
		var char = Rand.choice("rkc".split())
		var monster = make_monster(new_board, char)
		builder.place(monster, false, null, true, null, index)
		
	return new_board
		
func make_monster(parent, char: String):
	var tree = load("res://src/combat/monster.tscn") as PackedScene
	var monster = tree.instantiate()
	monster.get_node("Label").text = char
	parent.add_child(monster)
	return monster

func inspect_tile():
	var coord = hero.get_cell_coord()
	var data = (get_board() as RevBoard).get_cell_tile_data(0, coord)
	print("Data here is %s" % [[var_to_str(data), data.get_custom_data
("is_connector")]])

func conclude_game():
	## do a final bit of cleanup then show the Game Over screen
	$TurnQueue.shutdown()
	if hero.is_animating():
		print("can't shutdown quite yet, hero animating...")
		# nothing else to do: Actors free themselves after they die
		await hero.anims_done
		print("hero done animating!")
	var tree = get_tree() as SceneTree
	tree.change_scene_to_file("res://src/ui/game_over_screen.tscn")

func center_on_hero():
	find_child("Viewport").center_on_coord(hero.get_cell_coord())

func _input(_event):
	if Input.is_action_just_pressed("test-2"):
		inspect_tile()
		$HUD/InventoryScreen.fill_actor_items(hero)
		$HUD/InventoryScreen.show()
	elif Input.is_action_just_pressed("test"):
		print("Testing: 1, 2... 1, 2!")
		var item = Rand.choice(hero.get_items())
		hero.drop_item(item)
		print("%s dropped a %s" % [hero, item])
