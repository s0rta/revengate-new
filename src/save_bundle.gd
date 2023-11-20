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

## A saved game.
class_name SaveBundle extends Resource

const SAVE_DIR = "user://saved-games/"
const SAVE_FILE = "main_scene.tres"
const VERBOSE := true

@export var version := Consts.VERSION
@export var scene:PackedScene

func _ensure_dir(dir=SAVE_DIR):
	var da = DirAccess.open("user://")
	if not da.dir_exists(dir):
		da.make_dir(dir)


func save(root:Node):
	## Save the subtree starting at `root`. This does not need to be the game root.
	## Any nodes of the saved sub-tree might have its `owner` changed as a side-effect 
	## of calling this method.
	_ensure_dir()
	var path = SAVE_DIR + SAVE_FILE

	for child in root.find_children("", "Node", true, false):
		child.owner = root

	if VERBOSE:
		Utils.dlog_node(root, path + ".pre")
	
	scene = PackedScene.new()
	scene.pack(root)
	var ret_code = ResourceSaver.save(self, path)
	assert(ret_code == OK)

static func load(path=null):
	## Load a saved game and return the root `Node` of the scene.
	## This only turns the file into game objects. It's up to the caller to register 
	## those objects with the game loop and with the UI.
	if path == null:
		path = SAVE_DIR + SAVE_FILE

	# TODO: verify that the version is compatible with the current game
	var bundle = load(path)
	var root = bundle.scene.instantiate()

	if VERBOSE:
		Utils.dlog_node(root, path + ".post")

	return root	
