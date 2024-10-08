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

class_name Phantruch extends Actor

func die():
	for item in get_items(["vital-assemblage"], ["broken"]):
		item.wreck()
	# all inventory except the vital assemblage dissapears into another plane of existence.
	for item in get_items(null, ["vital-assemblage"]):
		item.reparent($/root)
		item.queue_free()
	return super()
