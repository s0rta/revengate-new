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

func act(actor: Actor):
	var hero = $"/root/Main/Hero"
	var board = $"/root/Main/Board"
	if hero == null or board == null:
		# we're are not in a complete scene
		return null

	var here = RevBoard.canvas_to_board(actor.position)
	var there = RevBoard.canvas_to_board(hero.position)
	var path = board.path(here, there)
	if path != null and path.size() > 1:
		return actor.move_to(path[1])
