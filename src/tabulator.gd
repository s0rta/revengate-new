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

## A registry of world events, including things that happened across multiple games.

## A tabulator was a machine to sort and organize punch cards. The first one was developped in the 
## late 19th century by Herman Hollerith before he founded the company that would later become IBM 
## to manufacture such machines.
class_name Tabulator extends Resource
const FILE_PATH = "user://global_facts.tres"

@export var allow_cheats := false
@export var enable_shaders := true
@export var text_size: Consts.TextSizes = Consts.TextSizes.UNSET
@export var dyn_lights: Consts.Lights = Consts.Lights.SOFT_SHADOWS

static func load() -> Tabulator:
	var da = DirAccess.open("user://")
	if da.file_exists(FILE_PATH):
		var tabulator = ResourceLoader.load(FILE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
		return tabulator
	else:
		return Tabulator.new()

static func clear():
	## Remove all records from the Tabulator data store.
	DirAccess.remove_absolute(get_abs_path())

static func get_abs_path():
	return ProjectSettings.globalize_path(FILE_PATH)

func save():
	var ret_code = ResourceSaver.save(self, FILE_PATH)
	assert(ret_code == OK)

