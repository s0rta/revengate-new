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
		if Utils.has_tags(spell, ["attack"]):
			await _target_and_cast()
		else:
			spell.cast()
			Tender.hero.finalize_turn(true)

func _target_and_cast():
	var board = Tender.hero.get_board()
	var index = board.make_index()
	var here = Tender.hero.get_cell_coord()
	var coords = board.visible_coords(here, spell.range)
	board.highlight_cells(coords, "mark-target-bad")

	var actor_coords = coords.filter(index.actor_at)
	board.highlight_cells(actor_coords, "mark-target-good")
	
	coords.append(here)
	var surveyor = Tender.hud.get_gesture_surveyor()
	var res = await surveyor.start_capture_coord("Cast %s where?" % spell.caption, coords)

	if res.success:
		var other = index.actor_at(res.coord)
		if other != null:
			spell.cast_on(other)
		else:
			spell.cast_at(res.coord)
		Tender.hero.finalize_turn(true)
	else:
		board.clear_highlights()
