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
	%VersionLabel.text = Consts.VERSION
	if Utils.is_debug():
		%VersionLabel.text += " debug"
	Tender.reset()
	Tender.full_game = true
	
	%ResumeButton.visible = SaveBundle.has_file()

func start_new_game():
	get_tree().change_scene_to_file("res://src/main.tscn")
	
func resume_game():
	# make sure the version is the same
	var bundle = SaveBundle.load() as SaveBundle
	if bundle.version != Consts.VERSION:
		%BadSaveVersionDiag.popup_centered()
		await %BadSaveVersionDiag.confirmed
		print("Looks like we can proceed...")
		# FIXME: hide the diag on accept
	# if so, put the data in the tender, then change scene
	pass # Replace with function body.

func _on_credits_button_pressed():
	get_tree().change_scene_to_file("res://src/ui/credits_screen.tscn")

func _on_license_button_pressed():
	get_tree().change_scene_to_file("res://src/ui/license_screen.tscn")

func _on_privacy_button_pressed():
	get_tree().change_scene_to_file("res://src/ui/privacy_screen.tscn")


func _on_bad_save_version_diag_canceled():
	%BadSaveVersionDiag.confirmed.emit()
