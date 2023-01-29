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

## a screen to show the known stats about a NPC or a monster
extends Control

func _input(event):
	# We are not truly modal, so we prevent keys from sending action to the game board
	# while visible.
	if visible and event is InputEventKey:
		accept_event()

func popup():
	show()

func _on_back_button_pressed():
	hide()
	
func clear():
	## Remove traces of the previous actor
	%DrawingLabel.text = "?"
	%StrengthLabel.text = "Strength:?"
	%HealthLabel.text = "Health:?"
	%AgilityLabel.text = "Agility:?"
	%DescLabel.text = "???"
	
func _make_img_text(img_path):
	## Convert an image path to BBCode that will display reasonably well.
	var size = %DrawingLabel.size
	return "[img=%sx%s]%s[/img]" % [size.x, size.y, img_path]
	
func fill_with(actor:Actor):
	## put the stats of actor all over the place
	if actor.bestiary_img:
		%DrawingLabel.text = _make_img_text(actor.bestiary_img)
	%HealthLabel.text = "Health (typical): %s" % actor.health_full
	%StrengthLabel.text = "Strength: %s" % actor.strength
	%AgilityLabel.text = "Agility: %s" % actor.agility
	if actor.description:
		%DescLabel.text = actor.description
	else:
		%DescLabel.text = "???"
	
