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

class_name VictoryScreen extends Control

signal start_next_chapter

func popup(game_over:bool):
	%EndingLabel.visible = game_over
	%QuitButton.visible = game_over
	%GameOverLabel.visible = game_over
	%VictoryLabel.visible = not game_over
	%NextButton.visible = not game_over
	%NextChapterLabel.visible = not game_over
	%ScrollView.get_v_scroll_bar().value = 0
	if Tender.hero_stats:
		%GameSummaryLabel.text = Utils.make_game_summary()
	else:
		%GameSummaryLabel.text = ""
	$VictorySound.play()
	show()
	
func show_main_screen():
	get_tree().change_scene_to_file("res://src/ui/start_screen.tscn")

func _on_next_button_button_up():
	emit_signal("start_next_chapter")
	hide()
