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

extends SpecialEffect

func _ready():
	var anim := get_tree().create_tween()
	anim.set_parallel()
	anim.set_trans(Tween.TRANS_SINE)
	anim.tween_property(self, "rotation", PI*20, max_screen_time*1.1)
	anim.set_trans(Tween.TRANS_LINEAR)
	anim.tween_property(self, "modulate:a", 0.0, max_screen_time)
	super()
