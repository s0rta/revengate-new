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
	if OS.has_feature("web"):
		# That button shuts down the engine, but it does not close the tab so 
		# it's just confusing. Better let the player close the tab with the browser 
		# shortcut on HTML5 exports.
		%QuitButton.hide()
	%VersionLabel.text = Consts.VERSION
	if Utils.is_debug():
		%VersionLabel.text += " debug"
	Tender.reset()
	Tender.full_game = true
	
	%ResumeButton.visible = SaveBundle.has_file()
	if OS.has_feature("mobile"):
		_expand_text_controls()

func _expand_text_controls():
	## Make all text controls bigger. 
	## We typically need this on devices with very small screens or with very high DPI.
	var size = Utils.screen_size()
	var narrow_side = min(size.x, size.y)
	var alt_theme
	if narrow_side > 7.0:
		# this is a really big screen, default controls are fine
		return
	elif narrow_side > 4.5:
		alt_theme = load("res://src/ui/theme_big.tres")
	else:
		alt_theme = load("res://src/ui/theme_really_big.tres")
	var theme = ThemeDB.get_project_theme()
	theme.merge_with(alt_theme)

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

func _on_about_button_pressed():
	get_tree().change_scene_to_file("res://src/ui/about_screen.tscn")

func _on_bad_save_version_diag_canceled():
	%BadSaveVersionDiag.confirmed.emit()

func _on_cant_load_diag_canceled():
	%CantLoadDiag.confirmed.emit()

func _on_quit_button_button_up():
	get_tree().quit()
	
