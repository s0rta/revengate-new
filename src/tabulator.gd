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

extends Node

## A registry of world events, inluding things that happened across multiple games.

## A tabulator was a machine to sort and organize punch cards. The first one was developped in the 
## late 19th century by Herman Hollerith before he founded the company that would later become IBM 
## to manufacture such machines.
class_name Tabulator
const fpath = "user://world_events.data"

func getv(key, default=null):
	var values = get_content()
	return values.get(key, default)
	
func setv(key, val):
	var values = get_content()
	values[key] = val
	save_content(values)

func get_content():
	if FileAccess.file_exists(fpath):
		var store = FileAccess.open(fpath, FileAccess.READ)
		return str_to_var(store.get_as_text())
	else:
		return {}
		
func save_content(values):
	var store = FileAccess.open(fpath, FileAccess.WRITE)
	store.store_string(var_to_str(values))

func get_abs_path():
	return ProjectSettings.globalize_path(fpath)
	
