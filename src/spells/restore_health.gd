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

class_name RestoreHealth extends Spell

const HEALTH_GAIN = 15

func _ready():
	super()
	mana_cost = 8
	tags.append("healing")

func cast():
	var here = me.get_cell_coord()
	var gain = min(HEALTH_GAIN, me.health_full - me.health)
	me.update_health(gain)
	Tender.viewport.effect_at_coord("magic_sfx_02", here)
	me.use_mana(mana_cost)
