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

## Get closer to another actor.
class_name Approaching extends Traveling

@export var other_id := 0
var other:Actor

func _init(other_:Actor=null, path_=null, actor=null, priority_=null, ttl_=null):
	var dest_ = Consts.COORD_INVALID
	if other_ != null:
		other = other_
		other_id = other.actor_id
		dest_ = other.get_cell_coord()
		dest_str = other.get_short_desc()
	super(dest_, path_, actor, priority_, ttl_)
	free_dest = false
	perceivable = true

func _turns_left():
	return max(0, path.size() - me.get_max_action_range(other))

func refresh(_turn):
	var board = me.get_board()
	
	if other_id and other == null:
		for actor in board.get_actors():
			if actor.actor_id == other_id:
				other = actor
				break
	
	if not me.perceives(other):
		if not arrived and not unreachable:
			add_hero_message("Stopped traveling: you don't know where %s went." % dest_str, 
							Consts.MessageLevels.CRITICAL)
		_invalidate()
	elif other == null or not other.is_alive():
		if not arrived and not unreachable:
			add_hero_message("Stopped traveling: your urge to get closer to %s went away with their demise." % dest_str, 
							Consts.MessageLevels.CRITICAL)
		_invalidate()
	elif board.dist(me, other) <= me.get_max_action_range(other):
		arrived = true
		_invalidate()
	else:
		dest_str = other.get_short_desc()
		dest = other.get_cell_coord()	
	super(_turn)
