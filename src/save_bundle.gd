# Copyright © 2023-2024 Yannick Gingras <ygingras@ygingras.net> and contributors

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

const SAVE_DIR_PARTS = ["user://saves/", "current/"]
const STALE_DIR_PARTS = ["user://saves/", "stale/"]  # an old save file that is not valid anymore

# TODO: can't construct this from SAVE_DIR_PARTS, but a static function could
const SAVE_PATH_PARTS = ["user://saves/", "current/", "bundle.tres"]

@export var version := Consts.VERSION
@export var turn:int
@export var active_board_id:int
@export var start_board_id:int
@export var tallies:Dictionary

@export var kills:Dictionary
@export var sentiments:SentimentTable
@export var quest_tag: String
@export var quest_is_active: bool
@export var seen_locs: Array
@export var nb_cheats := 0
@export var play_secs: float

var path:String  # where the Bundle should be serialized
var root:Node  # the root passed to save()

static func _ensure_dir(parts:Array):
	var path = ""
	for part in parts:
		path = Utils.path_join(path, part)
		if not DirAccess.dir_exists_absolute(path):
			DirAccess.make_dir_absolute(path)

static func full_path():
	return Utils.path_join_all(SAVE_PATH_PARTS)

static func save(board:RevBoard, start_board_id:int, turn:int, 
				tallies:Dictionary, kills:Dictionary, 
				sentiments:SentimentTable, quest_tag:String, quest_is_active:bool,
				seen_locs:Array, nb_cheats:int, play_secs:float):
	## Save a game. 
	## The whole subtree starting at `root` is saved. 
	## This does not need to be the game root.
	## Any nodes of the saved sub-tree might have its `owner` changed as a side-effect 
	## of calling this method.
	## Return the new SaveBundle resource after saving it to disk.
	var bundle = SaveBundle.new()
	bundle.active_board_id = board.board_id
	bundle.start_board_id = start_board_id
	bundle.turn = turn
	bundle.tallies = tallies
	bundle.kills = kills
	bundle.sentiments = sentiments
	bundle.quest_tag = quest_tag
	bundle.quest_is_active = quest_is_active
	bundle.seen_locs = seen_locs
	bundle.nb_cheats = nb_cheats
	bundle.play_secs = play_secs

	bundle._ensure_dir(SAVE_DIR_PARTS)
	var path = full_path()
	bundle.path = path

	save_board(board)
	bundle.flush()
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

	return bundle

static func remove():
	## Delete the saved game at the default path
	## Silently do nothing if there is no saved game file.
	if has_file():
		var stale_dir = Utils.path_join_all(STALE_DIR_PARTS)
		DirAccess.rename_absolute(Utils.path_join_all(SAVE_DIR_PARTS), stale_dir)
		Utils.remove_dir(stale_dir)

static func has_file():
	## Return whether a save file exists
	var path = ""
	for part in SAVE_PATH_PARTS:
		path = Utils.path_join(path, part)
		if not DirAccess.dir_exists_absolute(path) and not FileAccess.file_exists(path):
			return false
	return true

static func _board_path(board_id):
	var fname = "board-%s.scn" % board_id
	return Utils.path_join_all(SAVE_DIR_PARTS + [fname])
	
static func save_board(board:RevBoard):
	var path = _board_path(board.board_id)
	_ensure_dir(SAVE_DIR_PARTS)
	
	var seen = {board:true}
	for child in board.find_children("", "Node", true, false):
		seen[child] = true
		if not seen.has(child.owner) or child.owner is RevBoard and child.owner != board:
			child.owner = board
	
	var scene = PackedScene.new()
	scene.pack(board)
	ResourceSaver.save(scene, path)

static func load_board(board_id:int) -> RevBoard:
	var path = _board_path(board_id)
	var scene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert(scene, "Can't load board at %s" % path)

	var board:RevBoard = scene.instantiate()
	return board

func dlog_root(suffix=".log"):
	Utils.dlog_node(root, path + suffix)

func flush():
	## Send the data of this bundle to disk
	var ret_code = ResourceSaver.save(self, path)
	assert(ret_code == OK)
