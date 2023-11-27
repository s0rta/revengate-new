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

signal closed(acted:bool)

func _input(event):
	# We are not truly modal, so we prevent keys from sending action to the game board
	# while visible.
	if visible and event is InputEventKey:
		accept_event()

func popup():
	show()

func close():
	hide()
	emit_signal("closed", false)

func _on_back_button_pressed():
	close()
	
func clear():
	## Remove traces of the previous actor
	%NameLabel.text = "Name:"
	%DescLabel.text = "???"
		
func fill_with(item):
	## put the stats of item all over the place
	%NameLabel.text = "Name: %s" % item.get_short_desc()
	
	var desc = item.get_long_desc(Tender.hero.get_stat("perception"))
	if not desc.is_empty():
		%DescLabel.text = desc
	else:
		%DescLabel.text = "???"
	

func _on_padding_gui_input(event):
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		close()
