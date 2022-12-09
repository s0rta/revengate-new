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

extends Strategy
## Track the hero at every move.
class_name Tracking

var last_foe

func select_foe(actor, index):
	## Return a foe to attack from the current location of null if there are no suitable targets.
	var foes = index.actor_foes(actor, 1)
	if not foes.is_empty():
		if last_foe not in foes:
			last_foe = Rand.choice(foes)
		return last_foe
	else:
		return null
		
func act():
	var hero = $"/root/Main/Hero"
	var board = me.get_board()
	if hero == null or board == null:
		# we're are not in a complete scene
		return null	
		
	var index = board.make_index()
	# attack if we can, move towards the hero otherwise
	var foe = select_foe(me, index)
	if foe:
		return me.attack(foe)
	else:
		var here = me.get_cell_coord()
		var there = hero.get_cell_coord()
		var path = board.path(here, there)
		
		if path != null and path.size() > 1:
			return me.move_to(path[1])
