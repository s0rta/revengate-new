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

## Get closer to another actor.
class_name Approaching extends Traveling

var other:Actor

func _init(other_:Actor, path_=null, actor=null, priority_=null, ttl_=null):
	other = other_
	var dest_ = other.get_cell_coord()
	super(dest_, path_, actor, priority_, ttl_)
	free_dest = false
	perceivable = true
	dest_str = other.get_short_desc()

func _turns_left():
	return max(0, path.size() - me.get_max_action_range(other))

func refresh(_turn):
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
	else:
		dest = other.get_cell_coord()
	super(_turn)
