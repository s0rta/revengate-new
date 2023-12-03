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
@export var turn:int
@export var scene:PackedScene

var root:Node  # the root passed to save()

static func _ensure_dir(dir=SAVE_DIR):
	var da = DirAccess.open("user://")
	if not da.dir_exists(dir):
		da.make_dir(dir)

static func save(root:Node, turn:int, path=null):
	## Save a game. 
	## The whole subtree starting at `root` is saved. 
	## This does not need to be the game root.
	## Any nodes of the saved sub-tree might have its `owner` changed as a side-effect 
	## of calling this method.
	## Return the new SaveBundle resource after saving it to disk.
	var bundle = SaveBundle.new()
	bundle.turn = turn

	bundle._ensure_dir()
	if path == null:
		path = SAVE_DIR + SAVE_FILE

	if VERBOSE:
		Utils.dlog_node(root, path + ".zero", true)

	var seen = {root:true}
	for child in root.find_children("", "Node", true, false):
		seen[child] = true
		if not seen.has(child.owner) or child.owner is RevBoard:
			child.owner = root

	if VERBOSE:
		Utils.dlog_node(root, path + ".pre", false)
	
	bundle.scene = PackedScene.new()
	bundle.scene.pack(root)

	if VERBOSE:
		# This .tscn can be loaded in the editor to easily debug what the saved 
		# scene tree looks like.
		ResourceSaver.save(bundle.scene, path.replace(".tres", ".tscn"))

	var ret_code = ResourceSaver.save(bundle, path)
	assert(ret_code == OK)
	return bundle

static func load(path=null):
	## Load a saved game and return the root `Node` of the scene.
	## This only turns the file into game objects. It's up to the caller to register 
	## those objects with the game loop and with the UI.
	if path == null:
		path = SAVE_DIR + SAVE_FILE

	# TODO: verify that the version is compatible with the current game
	var bundle = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	bundle.root = bundle.scene.instantiate()

	if VERBOSE:
		# FIXME: paths are unreadable until we add the scene to the tree
		Utils.dlog_node(bundle.root, path + ".post")

	return bundle

func dlog_root(suffix=".log"):
	# FIXME: save the path on the bundle
	var path = SAVE_DIR + SAVE_FILE
	Utils.dlog_node(root, path + suffix)
