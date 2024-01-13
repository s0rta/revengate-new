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

# add lots of debug output and a few partial states files on disk
const VERBOSE := false

const SAVE_DIR = "user://saved-games/"
const SAVE_FILE = "main_scene"
const SAVE_EXT = ".tres"

# we won't actually lock those, only look for their presence
const BAD_SAVE_LOCK = "invalid.lock"
const GOOD_SAVE_LOCK = "valid.lock"

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
var temp_path: String

func _init(id=null):
	if id:
		temp_path = full_path(id)

static func _ensure_dir(dir=SAVE_DIR):
	var da = DirAccess.open("user://")
	if not da.dir_exists(dir):
		da.make_dir(dir)

static func full_path(id=null):
	if id:
		return "%s%s-%s%s" % [SAVE_DIR, SAVE_FILE, id, SAVE_EXT]
	else:
		return SAVE_DIR + SAVE_FILE + SAVE_EXT

static func save(root:Node, turn:int, kills:Dictionary, 
				sentiments:SentimentTable, quest_tag:String, quest_is_active:bool,
				seen_locs:Array, play_secs:float, immediate:bool=false):
	## Save a game. 
	## The whole subtree starting at `root` is saved. 
	## This does not need to be the game root.
	## Any nodes of the saved sub-tree might have its `owner` changed as a side-effect 
	## of calling this method.
	## `immediate`: send the bytes to disk this frame if true, async if false.
	## Return the new SaveBundle resource after saving it to disk.
	var bundle = SaveBundle.new(ResourceUID.create_id())
	bundle.turn = turn
	bundle.kills = kills
	bundle.sentiments = sentiments
	bundle.quest_tag = quest_tag
	bundle.quest_is_active = quest_is_active
	bundle.seen_locs = seen_locs
	bundle.play_secs = play_secs

	bundle._ensure_dir()
	var path = full_path()
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

	if immediate:
		bundle.flush()
	else:
		SaveBundle.flush_bundle.call_deferred(bundle)
	return bundle

static func flush_bundle(bundle:SaveBundle):
	## Static version of SaveBundle.flush()
	bundle.flush()

static func load(unpack:=false) -> SaveBundle:
	## Load a saved game and return the root `Node` of the scene.
	## This only turns the file into game objects. It's up to the caller to register 
	## those objects with the game loop and with the UI.
	var path = full_path()

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
	## Silently do nothing if there is no saved game file.
	
	# in HTML5, remove() is unrelable, so we make sure we don't re-use a file that should not be there
	FileAccess.open(SAVE_DIR+BAD_SAVE_LOCK, FileAccess.WRITE).close()
	
	if has_file():
		var da = DirAccess.open("user://")
		var path = full_path()
		da.remove(path)

static func clear_lock():
	var da = DirAccess.open(SAVE_DIR)
	if da and da.file_exists(SAVE_DIR+BAD_SAVE_LOCK):
		# since remove() is unreliable in HTML5, we move the lock out of the way before 
		# trying to delete it.
		da.rename(SAVE_DIR+BAD_SAVE_LOCK, SAVE_DIR+GOOD_SAVE_LOCK)
		da.remove(SAVE_DIR+GOOD_SAVE_LOCK)

static func has_file():
	## Return whether a save file exists
	var da = DirAccess.open("user://")
	if not da.dir_exists(SAVE_DIR):
		return false
	elif da.file_exists(SAVE_DIR+BAD_SAVE_LOCK):
		return false
	else:
		var path = full_path()
		return da.file_exists(path)

func dlog_root(suffix=".log"):
	Utils.dlog_node(root, path + suffix)

func flush():
	## Send the data of this bundle to disk
	var save_path = path
	if temp_path:
		save_path = temp_path
	var ret_code = ResourceSaver.save(self, save_path)
	assert(ret_code == OK)
	
	if temp_path:
		# Disk flushing can be done in defferedt calls. Since renaming is atomic, we know that
		# we won't corrupt the file if two saves happen to be flushed at the same time. We can't 
		# guarantee that the most recent flush is the one that is going to win, but we can live 
		# with that level of uncertainty.
		var da = DirAccess.open(SAVE_DIR)
		ret_code = da.rename(temp_path, path)
		assert(ret_code == OK)
	
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
