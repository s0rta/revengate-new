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

var full_game := false  # are we running the whole game or just an individual scene?
var save_bunle = null  # saved game to use rather than the starting board
var hero = null
var hud = null
var viewport = null
var kills := {}
var sentiments = null  # SentimentTable
var quest = null  # a Main.Quest instance

# End of game stats
var last_turn = null
var seen_locs := {}
var hero_stats = null
var hero_modifiers = null
var nb_cheats := 0  # the number of times the player has cheated
var play_secs := 0.0

# inter-chapter long narrations
var story_title = null
var story_path = null

# we try to be consistent with how values are perceived when you are unperceptive
var vague_vals_cache := {}

func reset(hero_=null, hud_=null, viewport_=null, sentiments_=null):
	hero = hero_
	hud = hud_
	viewport = viewport_
	quest = null
	kills = {}
	sentiments = sentiments_
	last_turn = null
	seen_locs.clear()
	nb_cheats = 0
	hero_stats = null
	hero_modifiers = null
	play_secs = 0.0
	story_title = null
	story_path = null

func pre_game(story_title_, story_path_):
	reset()
	story_title = story_title_
	story_path = story_path_
