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

@tool
@icon("res://assets/opencliparts/flame_warning.svg")

## An effect that paralizes the victim for a few turns
class_name Stun extends Effect

func apply(actor):
	super(actor)
	# TODO make effect Effect general enough to auto add strategies
	var strat = Paralized.new(actor, 1.0, nb_turns)
	actor.add_strategy(strat)
