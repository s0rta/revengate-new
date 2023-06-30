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

@icon("res://assets/dcss/magic_bolt_5.png")
class_name Spell extends Node

# TODO: would be nice to export those, but then subclasses have to be inherited scenes, 
#   not just subclasses
var mana_cost := 1  # base cost before modifiers from devices are added
var damage := 0
var damage_family: Consts.DamageFamily
var tags:Array[String]
var skill := "channeling"

var me: Actor  # the owner of this spell

func _init(actor=null):
	if actor and actor is Actor:
		me = actor

func _ready():
	# try to auto detect the actor
	if not me:
		var parent = get_parent()
		if parent is Actor:
			me = parent
	assert(me, "Spells must be connected to an Actor")

func has_reqs():
	## Return whether the actor can "pay" for this spell. 
	## The base class only looks for mana. Subclasses should check for more elaborate requirements.
	return me.has_mana(mana_cost)

func cast():
	## Activate the spell.
	## Must be overloaded by subclasses.
	assert(false, "not implemented")
