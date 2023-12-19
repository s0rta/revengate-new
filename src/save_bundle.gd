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
const VERBOSE := false

@export var version := Consts.VERSION
@export var turn:int
@export var scene:PackedScene

@export var kills:Dictionary
@export var sentiments:SentimentTable
@export var quest_tag: String
@export var quest_is_active: bool
@export var seen_locs: Array
@export var play_secs: float

var path:String  # where the Bundle should be serialized
var root:Node  # the root passed to save()

static func _ensure_dir(dir=SAVE_DIR):
	var da = DirAccess.open("user://")
	if not da.dir_exists(dir):
		da.make_dir(dir)

static func save(root:Node, turn:int, kills:Dictionary, 
				sentiments:SentimentTable, quest_tag:String, quest_is_active:bool,
				seen_locs:Array, play_secs:float):
	## Save a game. 
	## The whole subtree starting at `root` is saved. 
	## This does not need to be the game root.
	## Any nodes of the saved sub-tree might have its `owner` changed as a side-effect 
	## of calling this method.
	## Return the new SaveBundle resource after saving it to disk.
	var bundle = SaveBundle.new()
	bundle.turn = turn
	bundle.kills = kills
	bundle.sentiments = sentiments
	bundle.quest_tag = quest_tag
	bundle.quest_is_active = quest_is_active
	bundle.seen_locs = seen_locs
	bundle.play_secs = play_secs

	bundle._ensure_dir()
	var path = SAVE_DIR + SAVE_FILE
	bundle.path = path

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

static func load(unpack:=false) -> SaveBundle:
	## Load a saved game and return the root `Node` of the scene.
	## This only turns the file into game objects. It's up to the caller to register 
	## those objects with the game loop and with the UI.
	var path = SAVE_DIR + SAVE_FILE

	var bundle = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if bundle == null:
		# loading failed and it's really hard to convert the Godot errors into something that 
		# would make sense to the player
		return null
	bundle.path = path

	if unpack:
		bundle.unpack()

	return bundle

static func remove():
	## Delete the saved game at the default path
	if has_file():
		var da = DirAccess.open("user://")
		var path = SAVE_DIR + SAVE_FILE
		da.remove(path)

static func has_file():
	## Return whether a save file exists
	var da = DirAccess.open("user://")
	if not da.dir_exists(SAVE_DIR):
		return false
	else:
		var path = SAVE_DIR + SAVE_FILE
		return da.file_exists(path)

func dlog_root(suffix=".log"):
	Utils.dlog_node(root, path + suffix)
	
func unpack() -> Node:
	## Instantiate the root of the saved scene.
	## Return the root.
	root = scene.instantiate()

	if VERBOSE:
		# FIXME: this is of limited use at unpacking time since node paths will 
		#   be empty until we add the scene to a tree
		Utils.dlog_node(root, path + ".post")

	return root

func restore_actors():
	## Do a bit if sub-node cleanup on all actors.
	for board in root.find_children("", "RevBoard", true, false):
		for actor in board.find_children("", "Actor", false, false):
			actor.restore()
			
