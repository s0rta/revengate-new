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

## Pick a random foe from a different faction, fight them until either you or them die.
class_name Dueling extends Strategy

var foe = null

func refresh(_turn):
	if foe == null or not foe.is_alive():
		var index = me.get_board().make_index()
		select_foe(me, index)

func is_valid():
	return foe != null and super()

func act() -> bool:	
	if me.get_board().dist(me, foe) == 1:
		await me.attack(foe)
		return true
	else:
		return me.move_toward_actor(foe)

func select_foe(actor, index:RevBoard.BoardIndex):
	## Return a foe to attack from the current location of null if there are no suitable targets.
	var actors = index.get_actors()
	actors.shuffle()
	for other in actors:
		if other != me and other.is_alive() and other.faction != me.faction:
			foe = other
			return 
	foe = null  # couldn't find anyone worth fighting with
		
