# Copyright © 2022-2023 Yannick Gingras <ygingras@ygingras.net> and contributors

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

extends Strategy
## Go to a specific destination, abort if the destination becomes unreachable.
class_name Traveling

var dest: Vector2i
var path
var arrived = false
var unreachable := false  # have we failed to find a valid path?
var updated := false  # have we refreshed the internal data this turn?

func _init(dest_: Vector2i, path_=null, actor=null, priority_=null, ttl_=null):
	super(actor, priority_, ttl_)
	dest = dest_
	if path_:
		# not setting null paths; we try to generate a new one before deciding if the strategy
		# is valid.
		_set_path(path_)
	# We have to get a new path at the start of each turn since things might have move around 
	# quite a bit.
	me.turn_done.connect(_expire_path)
	me.was_attacked.connect(_invalidate, CONNECT_ONE_SHOT)

func _invalidate(_arg):
	unreachable = true
			
func _set_path(path_):
	if path_:
		assert(path_[-1] == dest, "Path must lead to the destination")
		if path_[0] == me.get_cell_coord():
			path_.pop_front()
	path = path_
	updated = true

func _make_path():
	var board = me.get_board()
	assert(board, "Traveling only works on scenes with a board")
	var path_ = board.path(me.get_cell_coord(), dest)
	if path_ == null:
		unreachable = true
	return path_

func _expire_path():
	path = null
	updated = false

func is_expired():
	return arrived or unreachable or super.is_expired()

func is_valid():
	print("Checking if %s is still valid." % self)
	if not arrived and not updated:
		_set_path(_make_path())
	return super.is_valid() and path and not arrived and not unreachable

func act():
	print("traveling towards %s" % RevBoard.coord_str(dest))
	if path.size():
		var there = path[0]
		if there == dest:
			arrived = true
		return me.move_to(there)
	else:
		return null
