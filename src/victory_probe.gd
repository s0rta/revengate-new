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

## Monitor the progress of the game against quest objectives
class_name VictoryProbe extends Node

signal end_of_chapter(victory, game_over)
var hero: Actor

func has_quest_item(actor:Actor):
	for item in actor.get_items(["quest-item"]):
		if item.char == "𝌕":
			return true
	return false
	
func reached_top_level(current_board:RevBoard):
	return current_board.depth == 0

func assay_victory(current_board:RevBoard):
	if hero == null:
		return
	if reached_top_level(current_board):
		var mem = Tender.hero.mem
		if (has_quest_item(hero) 
				or mem.recall("accountant_yeilded") != null 
				or mem.recall("accountant_died") != null):
			end_of_chapter.emit(true, false)
		elif mem.recall("accountant_met_salapou") != null:
			end_of_chapter.emit(false, false)

func on_actor_died(board:RevBoard, coord:Vector2i, tags:Array[String]):
	print("an actor died! Their tags were: %s" % [tags])
	if "quest-boss-retznac" in tags:
		end_of_chapter.emit(true, true)
