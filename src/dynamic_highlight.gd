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

## A tile highlight that draws itself with primitives rather than a sprite.
class_name DynHighlight extends Node2D

func _draw() -> void:
	var rect = Rect2(-16, -16, 32, 32)
	draw_rect(rect, "#ffffff28")
	
	var k = 4
	for i in k:
		var size = Vector2.ONE * (32 - k + i)
		rect = Rect2(-size / 2.0, size)
		draw_rect(rect, "#ffffff18", false, k - i)
