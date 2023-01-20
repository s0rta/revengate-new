# Copyright © 2022 Yannick Gingras <ygingras@ygingras.net> and contributors

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

extends Node

func _ready():
	find_child("VersionLabel").text = Consts.VERSION
	if not $Tabulator.getv("early-stage-disclaimer"):
		$DisclaimerDia.popup_centered()
		$Tabulator.setv("early-stage-disclaimer", true)
	
func start_new_game():
	get_tree().change_scene_to_file("res://src/ui/intro_screen.tscn")
	
func _on_credits_button_pressed():
	get_tree().change_scene_to_file("res://src/ui/credits_screen.tscn")

func _on_license_button_pressed():
	get_tree().change_scene_to_file("res://src/ui/license_screen.tscn")

func _on_privacy_button_pressed():
	get_tree().change_scene_to_file("res://src/ui/privacy_screen.tscn")
