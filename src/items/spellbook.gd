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
## an item that can teach you how to use a new spell
class_name Spellbook extends Item

@export var mana_boost := 10
@onready var spells:Array = find_children("", "Spell", false, false)

func _get_configuration_warnings():
	var warnings = []
	if spells.is_empty():
		warnings.append("This book has not spell child nodes!")
	return warnings

func activate_on_actor(actor:Actor):
	if actor.get_skill("channeling") < Consts.SkillLevel.INITIATE:
		actor.set_skill("channeling", Consts.SkillLevel.INITIATE)
	actor.mana_full += mana_boost
	for spell_class in spells:
		var spell = spell_class.duplicate()
		actor.add_spell(spell)
		actor.add_message("%s learned the %s spell" % [actor.caption, spell.get_short_desc()])
	actor.refocus()
	super(actor)
