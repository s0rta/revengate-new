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


## A running count of cards that have been drawn or have been spoken for (held)
class_name Tally extends Resource

@export var hold_counts := {}  # card -> nb_holds mapping
@export var draw_counts := {}  # card -> nb_draws mapping

func _to_string():
	return "<Tally with %d holds, %d draws>" % [len(hold_counts), len(draw_counts)]

func ddump():
	print("holds: %s" % [hold_counts])
	print("draws: %s" % [draw_counts])
