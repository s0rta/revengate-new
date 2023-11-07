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

## Go to a specific destination, abort if the destination becomes unreachable.
class_name Traveling extends Strategy

var dest: Vector2i
var path
var arrived = false
var unreachable := false  # have we failed to find a valid path?
var updated := false  # have we refreshed the internal data this turn?
var free_dest := true  # does the destination have to be free?
var dest_str := "destination"
var board

func _init(dest_: Vector2i, path_=null, actor=null, priority_=null, ttl_=null):
	super(actor, priority_, ttl_)
	dest = dest_
	board = me.get_board()
	cancellable = true
	if path_:
		# not setting null paths; we try to generate a new one before deciding if the strategy
		# is valid.
		_set_path(path_)
	# We have to get a new path at the start of each turn since things might have move around 
	# quite a bit.
	me.turn_done.connect(_expire_path)
	me.was_attacked.connect(_on_being_attacked, CONNECT_ONE_SHOT)

func _invalidate(_arg=null):
	unreachable = true
	if me:
		me.emit_signal("strategy_expired")

func _on_being_attacked(_arg):
	if is_valid():
		add_hero_message("Stopped traveling: under attack!", Consts.MessageLevels.CRITICAL)
	_invalidate(_arg)

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
	var path_ = board.path_perceived(me.get_cell_coord(), dest, me, free_dest)
	if path_ == null:
		if not arrived and not unreachable:
			add_hero_message("Stopped traveling: %s unreachable." % dest_str, 
							Consts.MessageLevels.CRITICAL)
		_invalidate()
	return path_

func _expire_path():
	path = null
	updated = false

func is_expired():
	return arrived or unreachable or super()

func is_valid():
	if not super():
		return false
	if not arrived and not updated:
		_set_path(_make_path())
	return path and not arrived and not unreachable

func refresh(_turn):
	if board != me.get_board():
		_invalidate()
	if unreachable or arrived:
		queue_free()

func _turns_left():
	return path.size()

func act():
	var nb_steps = _turns_left()
	if nb_steps:
		var msg = "%s is travelling towards %s." % [me.get_short_desc(), dest_str]
		if nb_steps > 1:
			msg += " Arriving in %d turn(s)." % (nb_steps - 1)
		add_hero_message(msg, Consts.MessageLevels.INFO, ["strategy"])

		if nb_steps <= 1:
			arrived = true
		var there = path[0]
		return me.move_to(there)
	else:
		return null
