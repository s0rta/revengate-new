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

class_name EndOfChapterScreen extends ModalScreen

signal start_next_chapter

func show_summary(quest, victory:bool, game_over:bool):
	%QuitButton.visible = game_over
	%NextButton.visible = not game_over
	if victory:
		%Title.text = "Victory!"
		%QuitButton.text = "Nice!"
	elif game_over:
		%Title.text = "Game Over!"
		%QuitButton.text = "Next..."
	else:
		%Title.text = "Failed!"
	%OutcomeLabel.text = ["You failed!", "You have made it!"][int(victory)]
	if victory:
		%MoreOutcomeLabel.text = quest.win_msg
	elif quest.fail_msg:
		%MoreOutcomeLabel.text = quest.fail_msg
	else:
		%MoreOutcomeLabel.text = ""
	%MoreOutcomeLabel.visible = not %MoreOutcomeLabel.text.is_empty()
		
	%NextChapterLabel.visible = victory and not game_over
	%ConqueredLabel.visible = victory and game_over
	%TryAgainLabel.visible = not victory and game_over
	%QuitButton.visible = game_over
	%NextButton.visible = not game_over
	%ScrollView.get_v_scroll_bar().value = 0
	if Tender.hero_stats:
		%GameSummaryLabel.text = Utils.make_game_summary()
	else:
		%GameSummaryLabel.text = ""
	if victory:
		$WinSound.play()
	else:
		$FailSound.play()
	popup()

func close(has_acted:=false):
	emit_signal("start_next_chapter")
	super(has_acted)

func show_main_screen():
	get_tree().change_scene_to_file("res://src/ui/start_screen.tscn")

func _on_next_button_button_up():
	close()
