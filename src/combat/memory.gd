# Copyright © 2023–2024 Yannick Gingras <ygingras@ygingras.net> and contributors

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

@icon("res://src/combat/memory.png")
## A store for events affecting the world and individual actors.
## Termilogy:
##   - event: a string key to reference something that happened
##   - fact: a dict containing the `event` plus some extra data
class_name Memory extends Resource

enum Importance {
	TRIVIAL,      # probably won't remember it happened after 50 turns
	NOTABLE,
	INTERESTING,  # might forget in a year or so
	FASCINATING,
	CRUCIAL       # you can never forget who your mother is
}

# Importance -> nb_turns to forget the fact
const RELEVANCE_AGE = {
	Importance.TRIVIAL: 50, 
	Importance.NOTABLE: 250, 
	Importance.INTERESTING: 1000, 
	Importance.FASCINATING: 5000, 
	Importance.CRUCIAL: INF, 
}

@export_group("Internals")
# Entries can be null when a fact has been forgotten.
# This array is compacted from time to time to remove entries that have been forgotten
# or that are no longer relevant.
@export var _facts := []

func learn(event:String, turn, importance:=Importance.NOTABLE, data=null):
	## Store a recollection of `event`.
	if Rand.rstest(0.0005):
		gc(turn)
	var fact = {"event": event, "turn": turn, "importance": importance}
	if data:
		fact.merge(data)
	_facts.append(fact)

func forget(event, valid_pred=null):
	## Forget that `event` ever happened.
	## valid_pred: only facts that are true for this predicate are forgotten.
	var new_facts = []
	for i in len(_facts):
		if _facts[i] == null:
			continue
		if _facts[i].event == event and (valid_pred == null or valid_pred.call(_facts[i])):
			_facts[i] = null

func forget_all(events, valid_pred=null):
	## like forget() for multible events.
	for event in events:
		forget(event, valid_pred)

func clear():
	## Induce total amnesia
	_facts = []

func is_relevant(fact, current_turn) -> bool:
	## Return true if `fact` is still relevant.
	if fact == null:
		return false
	return (current_turn - fact.turn) < RELEVANCE_AGE[fact.importance]
	
func gc(current_turn):
	## Forget about facts that are too old to still be relevant.
	_facts = _facts.filter(is_relevant.bind(current_turn))
	
func recall(event, current_turn=null, valid_pred=null):
	## Return the latest fact about `event` or `null` if nothing is known about `event`
	## `current_turn`: if provided, only facts that are still relevant are considered.
	## `valid_pred`: only facts that are true with this callable are considered.
	return recall_any([event], current_turn, valid_pred)

func recall_any(events:Array[String], current_turn=null, valid_pred=null):
	## Return the latest fact about any of the `events` 
	## Return `null` if nothing is known about `events`
	## `current_turn`: if provided, only facts that are still relevant are considered.
	## `valid_pred`: only facts that are true with this callable are considered.
	for i in _facts.size():
		var fact = _facts[-i-1]
		if fact != null and fact.event in events:
			if current_turn:
				if is_relevant(fact, current_turn):
					if valid_pred == null:
						return fact
					elif valid_pred.call(fact):
						return fact
			else:
				return fact
	return null

func recall_all(event, current_turn=null) -> Array:
	## Return all the known facts about `event` in reverse chronological order
	## `current_turn`: if provided, only facts that are still relevant are considered.
	var facts := []
	for i in _facts.size():
		var fact = _facts[-i-1]
		if fact != null and fact.event == event:
			if current_turn:
				if is_relevant(fact, current_turn):
					facts.append(fact)
			else:
				facts.append(fact)
	return facts
	
func recall_nb(event, current_turn=null) -> int:
	## Return the number of facts about `event` that we know about.
	## `current_turn`: if provided, only facts that are still relevant are considered.
	# We could save a bit of space by directly counting rather than building the whole list
	# of facts, but this is plenty good until the profiler tells us that it's wrong.
	return len(recall_all(event, current_turn))	

func ddump_summary(current_turn=null, prefix=""):
	## `current_turn`: if provided, only relevant facts are considered
	## `prefix`: if provided, all output lines will start with it
	var counts = {}
	for fact in _facts:
		if current_turn == null or is_relevant(fact, current_turn):
			counts[fact["event"]] = counts.get(fact["event"], 0) + 1
	var pairs = []
	for event in counts:
		pairs.append([counts[event], event])
	pairs.sort()
	print("%sKnown events:" % prefix)
	for pair in pairs:
		print("%s- %s: %d" % [prefix, pair[1], pair[0]])
		
