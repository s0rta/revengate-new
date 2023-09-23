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

## Very common variables and game states that are used in a large number of game components.
## This script is autoloaded at `Tender`

## The tender cart of a train used to immediately follows a steam locomotive. It contained supplies and items that
## were used to keep the steam engine running properly, like coal, water, shovels, and tools.
extends Node

var hero = null
var hud = null
var viewport = null
var kills := {}
var sentiments = null  # SentimentTable
var chapter := 0

# End of game stats
var last_turn = null
var nb_locs = null
var hero_stats = null
var hero_modifiers = null

# inter-chapter long narrations
var story_title = null
var story_path = null

func reset(hero_=null, hud_=null, viewport_=null, sentiments_=null):
	hero = hero_
	hud = hud_
	viewport = viewport_
	chapter = 1
	kills = {}
	sentiments = sentiments_
	last_turn = null
	nb_locs = null	
	hero_stats = null
	hero_modifiers = null
	story_title = null
	story_path = null
	
func pre_game(story_title_, story_path_):
	reset()
	story_title = story_title_
	story_path = story_path_
