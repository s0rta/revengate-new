# Copyright © 2023-2024 Yannick Gingras <ygingras@ygingras.net> and contributors

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

## a screen to show the known stats about a NPC or a monster
extends ModalScreen
const EMPTY_IMG_TEXT = "\n[bgcolor=#ffffff][center]%s[/center][/bgcolor]\n"

# TODO: this should be discovered to make the layout more responsive to different screen sizes, 
#  but the first showing always has `size` and `custom_minimum_size` as (0, 0) before we `show()`, 
#  so we'll have to come up with something cleaver to do our discovery.
const IMG_HEIGHT = 537

func _on_back_button_pressed():
	close(false)

func clear():
	## Remove traces of the previous actor
	%DrawingLabel.text = "?"
	%NameLabel.text = "Name:"
	%StrengthLabel.text = "Strength:?"
	%HealthLabel.text = "Health:?"
	%AgilityLabel.text = "Agility:?"
	%PerceptionLabel.text = "Perception:?"
	%DescLabel.text = "???"
	
func _make_img_text(img_path):
	## Convert an image path to BBCode that will display reasonably well.
	var size = %DrawingLabel.size
	var background = %DrawingLabel.get_parent().find_child("Background")
	# TODO: we probably have to look at the aspect ratio of the image rather than 
	#   blindly passing width=0
	return "[bgcolor=#ffffff][center][img=%sx%s]%s[/img][/center][/bgcolor]" % [0, IMG_HEIGHT, img_path]
	
func show_actor(actor:Actor):
	## put the stats of actor all over the place
	if actor.bestiary_img:
		%DrawingLabel.text = _make_img_text(actor.bestiary_img)
	else:
		%DrawingLabel.text = EMPTY_IMG_TEXT % actor.char
	%NameLabel.text = "Name: %s" % actor.get_caption()
	var perception = Tender.hero.get_stat("perception")
	var plevel = CombatUtils.percep_level(perception)
	if plevel < Consts.PercepLevel.PERFECT and actor != Tender.hero:
		# you can't perceive other people's status as well as your own
		plevel = min(plevel - 1, Consts.PercepLevel.INEPT)
		
	if plevel >= Consts.PercepLevel.PERFECT:
		%HealthLabel.text = "Health: %s" % actor.health
	elif actor.health_full > 0:
		%HealthLabel.text = "Health (typical): %s" % actor.health_full
	else:
		%HealthLabel.text = "Health (typical): unknown"
	var strength = actor.get_stat("strength")
	%StrengthLabel.text = "Strength: %s" % Utils.vague_value(strength, strength/100.0, perception)
	var agility = actor.get_stat("agility")
	%AgilityLabel.text = "Agility: %s" % Utils.vague_value(agility, agility/65.0, perception)
	var percep = actor.get_stat("perception")
	%PerceptionLabel.text = "Perception: %s" % Utils.vague_value(percep, percep/100.0, perception)
	if actor.description:
		# TODO: convert description to percep_lvl
		%DescLabel.text = actor.description
	else:
		%DescLabel.text = "???"
		
	var conds = _sorted_conditions(actor.get_conditions())
	var cond_lines = conds.map(func (c): return "‣ " + c.summary(plevel))
	cond_lines.filter(func (l): return l)  # filter out empty lines
	if cond_lines:
		cond_lines = Utils.collapse_strings_fmt(cond_lines, len(cond_lines))
		%DescLabel.text += "\n\nConditions:\n%s" % ["\n".join(cond_lines)]
	popup()

func _sorted_conditions(conds):
	var elems = conds.map(func (c): return [c.condition_name, c.nb_turns, c])
	elems.sort()
	return elems.map(func (e): return e[-1])
	
