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

## Store and lookup for cross-faction and cross-actor sentiments. 
## Cross-faction sentiments are symetrical.
## Per-actor sentiments are not supported.
class_name SentimentTable extends Node

const OPINION_THRESHOLD = 0.25  # must be that far from 0 to not be neutral

# faction -> float
var _defaults := {Consts.Factions.BEASTS: -1}

# [fact_a, fact_b] -> float
@export var _cross_factions := {[Consts.Factions.LUX_CO, Consts.Factions.BEASTS]: -1,
						[Consts.Factions.LUX_CO, Consts.Factions.OUTLAWS]: -1, 
						[Consts.Factions.BEASTS, Consts.Factions.OUTLAWS]: 0, 
						[Consts.Factions.BEASTS, Consts.Factions.CIRCUS]: 0, 
						[Consts.Factions.BEASTS, Consts.Factions.NONE]: 0, 
					}

func _ready():
	# we guarantee symetrical sentiments by normalizing keys
	var pre_size = len(_cross_factions)
	for key in _cross_factions.keys():
		var norm_key = key.duplicate()
		norm_key.sort()
		if norm_key != key:
			_cross_factions[norm_key] = _cross_factions[key]
			_cross_factions.erase(key)
	assert(pre_size == len(_cross_factions), 
			("Normalizing sentiment keys failed. Do you have bi-directional"
			+ " sentiment records? Only one direction should be provided."))

func _get_faction(elem):
	if elem is int:
		return elem
	else: 
		return elem.get("faction")

func get_sentiment(from, to) -> float:
	## Return how `from` feels about `to` in -1..1
	## From and to and be actors or factions
	if from == to:
		return 1  # you need to play a different game if you can't love yourself

	var from_faction = _get_faction(from)
	var to_faction = _get_faction(to)

	if from_faction == to_faction:
		return 1
	
	var key = [from_faction, to_faction]
	key.sort()
	if _cross_factions.has(key):
		return _cross_factions[key]
	elif _defaults.has(from_faction):
		return _defaults[from_faction]
	else:
		return 0

func set_sentiment(from, to, value:float):
	## Record how `from` feels about `to` in -1..1
	assert(-1 <= value and value <= 1)
	var from_faction = _get_faction(from)
	var to_faction = _get_faction(to)
		
	if from_faction == to_faction:
		return

	var key = [from_faction, to_faction]
	key.sort()
	_cross_factions[key] = value
	
func is_neutral(from, to) -> bool:
	## Return whether `from` feels neutral towards `to`
	return abs(get_sentiment(from, to)) < OPINION_THRESHOLD
	
func is_friend(from, to) -> bool:
	## Return whether `from` considers `to` as a friend
	return get_sentiment(from, to) >= OPINION_THRESHOLD
	
func is_foe(from, to) -> bool:
	## Return whether `from` considers `to` as a foe
	return get_sentiment(from, to) <= -OPINION_THRESHOLD

func ddump():
	print("SentimentTable internals:")
	print("   defaults: %s" % _defaults)
	print("   cross-factions: %s" % _cross_factions)
