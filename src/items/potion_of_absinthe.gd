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

extends Item

func activate_on_actor(actor):
	var prev_drank = actor.mem.recall_all("drank_absinthe", actor.current_turn)
	actor.mem.learn("drank_absinthe", actor.current_turn, Memory.Importance.TRIVIAL)
	var nb_drank = len(prev_drank) + 1
	if nb_drank == 2:
		message = "Things around you seem sureal."
	elif nb_drank in [3, 4]:
		message = "Woah!"
		var effects = find_children("", "Effect", false, false)
		effects[0].perception = 140
	elif nb_drank > 4:
		message = "This doen't feel good anymore."
	super(actor)
