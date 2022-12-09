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
## Base class for strategies to automate the actions of an actor.
class_name Strategy
@icon("res://src/combat/strat.svg")


@export_range(0, 1) var priority := 0.0  # in 0..1
@export var ttl := -1  # turns till expiration of the strategy if >=0, infinite if negative

var me: Actor  # the actor being controlled by this strategy

func _init(actor=null, priority_=null, ttl_=null):
	if actor and actor is Actor:
		me = actor
	if priority_ != null:
		priority = priority_
	if ttl_ != null: 
		ttl = ttl_

func _ready():
	# try to auto detect the actor that this strategy is attached to
	if not me:
		var parent = get_parent()
		if parent is Actor:
			me = parent
	me.turn_done.connect(_update_expiration)
		
func _update_expiration():
	## check is this strategy has expired, do the cleanup if so
	if ttl > 0:
		ttl -= 1
	if is_expired() and me:
		me.turn_done.disconnect(_update_expiration)
		me.turn_done.connect(queue_free, CONNECT_ONE_SHOT)

func is_valid() -> bool:
	## return is the strategy is valid for the current turn
	return ttl != 0
	
func is_expired() -> bool:
	## Return whether the strategy has expired. 
	## An expired stratedy can't become valid again and will eventually be deleted.
	return ttl is int and ttl == 0

func act():
	assert(false, "act() must be re-implemented by subclasses")
