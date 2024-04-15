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

## Do nothing until you feel better or get significantly disturbed.
class_name Resting extends Strategy

@export var target_health := -1

func _init(actor=null, priority=null, ttl=null, target_health_=-1):
	cancellable = true
	target_health = target_health_
	super(actor, priority, ttl)
	me.was_attacked.connect(_on_being_attacked, CONNECT_ONE_SHOT)
	
func is_expired():
	if super():
		return true
	if target_health >= 0 and me.health >= target_health:
		return true
	return false

func act():
	if me == Tender.hero:
		var msg = "%s is meditating..." % [me.get_short_desc()]
		me.add_message(msg, Consts.MessageLevels.INFO, ["strategy"])
	return true

func _on_being_attacked(_arg):
	if is_valid():
		add_hero_message("Stopped resting: under attack!", Consts.MessageLevels.CRITICAL)
	ttl = 0
	me.strategy_expired.emit()
