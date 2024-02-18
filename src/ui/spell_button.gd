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

## A Button specifically made to cast a spell
class_name SpellButton extends Button

var spell:Spell

func _init(spell_):
	spell = spell_
	text =  spell.char
	theme_type_variation = "ProminentButton"
	focus_mode = Control.FOCUS_NONE
	button_up.connect(on_button_up)

func _ready():
	set_enabled()

func set_enabled(val=null):
	## Make this button enabled or disabled. 
	## For the button to be enabled, both val and spell.has_req() must be true.
	## if val is not provided, only spell.has_req() is considered.
	if val != null and not val:
		disabled = true
	else:
		disabled = not spell.has_reqs()

func on_button_up():
	if spell.has_reqs():
		spell.cast()
		Tender.hero.finalize_turn(true)
