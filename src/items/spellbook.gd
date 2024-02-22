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

extends Item

var spells= [RestoreHealth]

func activate_on_actor(actor:Actor):
	if actor.get_skill("channeling") < Consts.SkillLevel.INITIATE:
		actor.set_skill("channeling", Consts.SkillLevel.INITIATE)
	actor.mana_full += 10
	for spell_class in spells:
		var spell = spell_class.new()
		actor.add_spell(spell)
		actor.add_message("%s learned the %s spell" % [actor.caption, spell.get_short_desc()])
	actor.refocus()
	super(actor)
