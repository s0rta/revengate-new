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

## A "stack" of similar items treated indifenrently in the inventory screen
class_name ItemGrouping extends RefCounted

var items : Array[Item] = []

var consumable:
	get: 
		assert (not is_empty())
		return items[0].consumable

var switchable:
	get:
		assert (not is_empty())
		return items[0].switchable

var is_equipped:
	get:
		if is_empty() or items[0].get("is_equipped") == null:
			return null
		for item in items:
			if item.get("is_equipped"):
				return true
		return false
	set(val):
		# equipping from a groupping only applies to the top item
		assert(not is_empty())
		items[-1].is_equipped = val
		for i in len(items) - 1:
			items[i].is_equipped = false		

func _to_string():
	if is_empty():
		return "<grouping empty>"
	else:
		return "<group of %d %s(s)>" % [len(items), items[0].caption]

func is_empty() -> bool:
	return items.is_empty()

func add(item):
	items.append(item)

func top() -> Item:
	## Return the item at the top of the stack.
	assert(not is_empty())
	return items[-1]

func pop() -> Item:
	## Return the item at the top of the stack and remove it from this grouping
	assert(not is_empty())
	return items.pop_back()

func get_short_desc():
	var desc = top().get_short_desc()
	var size = len(items)
	if size == 1:
		return desc
	else:
		return "%dx %s" % [size, desc]

func toggle():
	assert(false, "not implemented")
	
