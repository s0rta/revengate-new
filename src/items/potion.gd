# Copyright © 2024 Yannick Gingras <ygingras@ygingras.net> and contributors

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

class_name Potion extends Item

func wreck():
	super()
	activate_on_coord(get_cell_coord())
	_dissipate()

func activate_on_coord(coord):
	var index = get_board().make_index()
	var actor = index.actor_at(coord)
	if actor:
		activate_on_actor(actor)
