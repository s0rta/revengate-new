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

@icon("res://assets/opencliparts/card_deck.svg")
## Factory to make card decks based on composable rules
class_name DeckBuilder extends Node

var hold_counts := {}  # card -> nb_holds mapping
var draw_counts := {}  # card -> nb_draws mapping

func _get_cards(node:Node, card_type):
	return node.find_children("", card_type, false, false)

func _add_all_cards(deck, cards, depth, world_loc:Vector3i, budget, rule=null):
	## Add all card direct children of `node` to `deck`
	## nb_occurences is adjusted according to `bugdet`
	for card in cards:
		assert(card.spawn_cost != 0, "Can only produce decks when spawn_cost is configured")
		var nb_occ = budget/card.spawn_cost
		if rule != null:
			if rule.max_board_occ != -1:
				nb_occ = min(nb_occ, rule.max_board_occ)
			if rule.max_dungeon_occ != -1:
				nb_occ = min(nb_occ, rule.max_dungeon_occ - nb_tied_occ(card))
		nb_occ = max(nb_occ, 0)
		if nb_occ > 0:
			deck.add_card(card, nb_occ)

func tally_draw(card, update_holds=false):
	## Record that `card` was just drawn.
	## if update_holds, one hold is released for the card
	if not draw_counts.has(card):
		draw_counts[card] = 0
	if update_holds and hold_counts.has(card):
		var hold = hold_counts[card]
		hold_counts[card] = min(0, hold-1)
	draw_counts[card] += 1

func set_hold(card, nb_occ=1):
	## Set a temporary hold on card. 
	## Held occurences will be considered as drawn when generating new decks.
	if not hold_counts.has(card):
		hold_counts[card] = 0
	hold_counts[card] += nb_occ
	
func clear_holds():
	## Release all the holds
	hold_counts = {}

func nb_tied_occ(card):
	## Return the number of unavailable copies of card: held+drawn.
	return hold_counts.get(card, 0) + draw_counts.get(card, 0)

func nb_mandatory_occ(card, rule, depth, world_loc:Vector3i):
	## Return how many occurences are mandated by a rule
		
	var dungeon_deficit = 0
	if (rule.min_dungeon_occ and depth == rule.max_depth) \
			or (rule.world_loc != Consts.LOC_INVALID and rule.world_loc == world_loc):
		dungeon_deficit = rule.min_dungeon_occ - nb_tied_occ(card)
	var nb_occ = max(0, rule.min_board_occ, dungeon_deficit)
	return nb_occ

func gen_mandatory_deck(card_type, depth, world_loc:Vector3i):
	## Return a deck of cards that must be fully distributed before any draw is
	##   done from the regular deck.
	## The mandatory deck is probabilistic and the order of cards is random.
	## Return an empty deck if there are no mandatory cards for the level.
	## Mandatory distribution rules take precedence over spawn_cost and budget is therefore ignored.
	var tally = tally_draw.bind(true)
	var deck = Deck.new(null, tally)
	# we skip cards that are direct children because there are no rules that would force 
	# those in the mandator deck
	for child in get_children():
		if child is CardRule:
			var rule = child
			for card in rule.find_children("", card_type, false):
				var nb_occ = nb_mandatory_occ(card, rule, depth, world_loc)
				if nb_occ:
					set_hold(card, nb_occ)
					deck.add_card(card, nb_occ)
	deck.normalize()
	return deck

func gen_deck(card_type, depth, world_loc:Vector3i, budget, extra_cards=[]):
	var deck = Deck.new(null, tally_draw)
	_add_all_cards(deck, _get_cards(self, card_type), depth, world_loc, budget)
	for child in get_children():
		if child is CardRule:
			var rule = child
			if rule.world_loc != Consts.LOC_INVALID and rule.world_loc != world_loc:
				continue
			if depth < child.min_depth:
				continue
			if child.max_depth != -1 and depth > child.max_depth:
				continue
			_add_all_cards(deck, _get_cards(rule, card_type), depth, world_loc, budget, rule)
	_add_all_cards(deck, extra_cards, depth, world_loc, budget)
	deck.normalize()
	return deck
