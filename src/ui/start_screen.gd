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

const BAD_VERS_MSG = ("The game version you are running (v%s) is different than the one used "
						+ "to save the game (v%s). We are going to try to load and convert the "
						+ "saved game, but this might fail. "
						+ "\n\nIf the game crashes after loading, you should select 'New Game!' "
						+ "rather than 'Resume' next time.")

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
	var bundle = SaveBundle.load(false) as SaveBundle
	if bundle == null:
		%CantLoadDiag.popup_centered()
		await %CantLoadDiag.confirmed
		return
		
	if bundle.version != Consts.VERSION:
		%BadSaveVersionDiag.set_text(BAD_VERS_MSG % [Consts.VERSION, bundle.version])
		%BadSaveVersionDiag.popup_centered()
		await %BadSaveVersionDiag.confirmed
		print("Looks like we can proceed...")

	if bundle.unpack() == null:
		%CantLoadDiag.popup_centered()
		await %CantLoadDiag.confirmed
		return

	Tender.save_bunle = bundle
	get_tree().change_scene_to_file("res://src/main.tscn")

func _on_credits_button_pressed():
	get_tree().change_scene_to_file("res://src/ui/credits_screen.tscn")

func _on_license_button_pressed():
	get_tree().change_scene_to_file("res://src/ui/license_screen.tscn")

func _on_privacy_button_pressed():
	get_tree().change_scene_to_file("res://src/ui/privacy_screen.tscn")

func _on_bad_save_version_diag_canceled():
	%BadSaveVersionDiag.confirmed.emit()

func _on_cant_load_diag_canceled():
	%CantLoadDiag.confirmed.emit()
