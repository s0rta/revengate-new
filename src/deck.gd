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

## A probabilist deck of options. Cards can be any Object, occurences can be floats.
class_name Deck extends RefCounted

var cards := []
var occurences := []  # how many of each cards do we have?
var tally_func = null  # to be called with a card as it's drawn

func _init(card_occs=null, tally_func_=null):
	## card_occs: an Array of [card, nb_copies] pairs
	if card_occs != null:
		for item in card_occs:
			add_card(item[0], item[1])
	tally_func = tally_func_

func _to_string():
	var elems = _card_summaries()
	if elems:
		return "<Deck with %d cards: %s>" % [len(elems), ", ".join(elems)]
	else:
		return "<Deck with 0 cards>"

func _card_name(card):
	var name = card.get("name")
	if name:
		return name
	else:
		return "%s" % card

func _card_summaries(sparse=true):
	var total = Utils.sum(occurences)
	var elems = []
	for i in len(cards):
		if sparse and occurences[i] <= 0.0:
			continue
		var pct = 100.0 * occurences[i] / total
		elems.append("%s: %0.2f (%0.1f%%)" % [cards[i].name, occurences[i], pct])
	return elems

func ddump(sparse=false):
	## Print the content of the deck. 
	## sparse: only print cards with non-zezo occurences
	var elems = _card_summaries(sparse)
	if elems:
		print("Cards in this deck:")
		for elem in elems:
			print("  " + elem)
	else:
		print("No cards in this deck!")

func validate_nb_copies(nb_copies):
	assert(nb_copies != INF and nb_copies != NAN, 
		"I have no idea what you want me to do with that nb_copies...")
	assert(nb_copies >= 0, "Negative occurences are not supported.")

func is_empty():
	for occ in occurences:
		if occ >= 1:
			return false
	return true

func add_card(card, nb_copies=1):
	validate_nb_copies(nb_copies)
	cards.append(card)
	occurences.append(nb_copies)

func add_copies(card, nb_copies):
	validate_nb_copies(nb_copies)
	var index = cards.find(card)
	if index == -1:
		add_card(card, nb_copies)
	else:
		occurences[index] += nb_copies

func normalize():
	## Adjust the content of the deck to be consistent with drawing rules. 
	## Cards with less than one occurence are removed.
	for i in len(occurences):
		if occurences[i] < 1:
			occurences[i] = 0

func draw():
	## Return a card after adjusting it's number of occurences. 
	## Return `null` when the deck is empty.
	if len(cards) == 0 or occurences.max() <= 0:
		return null
	var index = Rand.weighted_choice(range(len(cards)), occurences)
	occurences[index] -= 1
	if occurences[index] < 1:  # a card needs at least one full occurence to be drawn
		occurences[index] = 0
	var card = cards[index]
	if tally_func:
		tally_func.call(card)
	return card
