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
@export_category("Internals")
@export var start_health : int

func _ready():
	super()
	if me is Actor and start_health == null:
		start_health = me.health
	me.was_attacked.connect(_on_being_attacked, CONNECT_ONE_SHOT)

func _init(actor=null, priority=null, ttl=null, target_health_=-1):
	cancellable = true
	target_health = target_health_
	super(actor, priority, ttl)

func _dissipate():
	if me == Tender.hero:
		var health_gain = me.health - start_health
		var verb = "recovered"
		var level = Consts.MessageLevels.INFO
		if health_gain < 0:
			verb = "lost"
			level = Consts.MessageLevels.CRITICAL
		if health_gain:
			me.add_message("%s %s %d health while resting" % [me.caption, verb, health_gain], 
							level, 
							["msg:combat"])
	super()

func refresh(turn):
	super(turn)
	if start_health == null:
		start_health = me.health

func is_expired():
	if super():
		return true
	if target_health >= 0 and me.health >= target_health:
		return true
	return false

func act():
	if me == Tender.hero:
		var msg = "%s is meditating..." % [me.get_short_desc()]
		me.add_message(msg, Consts.MessageLevels.INFO, ["msg:strategy"])
	return true

func filter_message(text:String, 
					level:Consts.MessageLevels, 
					tags:Array):
	# block all regen messages since we'll post a summary at the end of the meditation
	return "msg:regen" not in tags

func _on_being_attacked(_arg):
	if is_valid():
		add_hero_message("Stopped resting: under attack!", Consts.MessageLevels.CRITICAL)
	ttl = 0
	me.strategy_expired.emit()
