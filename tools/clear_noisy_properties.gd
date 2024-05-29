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
## Detect and remove properties that have been unecessarily auto-set in the editor and 
## cause git diffs to be noisy between different devolopers.
extends EditorScript


func _run():
	for actor in get_scene().find_children("", "Actor", true, true):
		actor.mem = null
	for builder in get_scene().find_children("", "DeckBuilder", true, true):
		builder.tally = null
