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

var draw_counts := {}  # card -> nb_draws mapping

func _add_all_cards(deck, node:Node, depth, budget, card_type="Actor", rule=null):
	## Add all card direct children of `node` to `deck`
	## nb_occurences is adjusted according to `bugdet`

	for card in node.find_children("", card_type, false):
		assert(card.spawn_cost != 0, "Can only produce decks when spawn_cost is configured")
		var nb_occ = budget/card.spawn_cost
		if rule != null and rule.max_board_occ != -1:
			nb_occ = min(nb_occ, rule.max_board_occ)
		if rule != null:
			nb_occ -= nb_mandatory_occ(card, rule, depth)
			if rule.max_dungeon_occ != -1:
				nb_occ = min(nb_occ, rule.max_dungeon_occ - draw_counts.get(card, 0))
		nb_occ = max(nb_occ, 0)
		deck.add_card(card, nb_occ)

func tally_draw(card):
	## Record that `card` was just drawn
	if not draw_counts.has(card):
		draw_counts[card] = 0
	draw_counts[card] += 1

func nb_mandatory_occ(card, rule, depth):
	## Return how many occurences are mandated by a rule
		
	var dungeon_deficit = 0
	if rule.min_dungeon_occ and depth == rule.max_depth:
		dungeon_deficit = rule.min_dungeon_occ - draw_counts.get(card, 0)
	var nb_occ = max(0, rule.min_board_occ, dungeon_deficit)
	return nb_occ

func gen_mandatory_deck(card_type, depth):
	## Return a deck of cards that must be fully distributed before any draw is
	##   done from the regular deck.
	## The mandatory deck is probabilistic and the order of cards is random.
	## Return an empty deck if there are no mandatory cards for the level.
	## Mandatory distribution rules take precedence over spawn_cost and budget is therefore ignored.
	
	var deck = Deck.new(null, tally_draw)
	# we skip cards that are direct children because there are no rules that would force 
	# those in the mandator deck
	for child in get_children():
		if child is CardRule:
			var rule = child
			for card in rule.find_children("", card_type):
				var nb_occ = nb_mandatory_occ(card, rule, depth)
				if nb_occ:
					deck.add_card(card, nb_occ)
	deck.normalize()
	return deck

func gen_deck(card_type, depth, budget):
	var deck = Deck.new(null, tally_draw)
	_add_all_cards(deck, self, depth, budget, card_type)
	for child in get_children():
		if child is CardRule:
			var rule = child
			if depth < child.min_depth:
				continue
			if child.max_depth != -1 and depth > child.max_depth:
				continue
			_add_all_cards(deck, rule, depth, budget, card_type, rule)	
	deck.normalize()
	return deck

func gen_monster_deck(depth, budget):
	return gen_deck("Actor", depth, budget)

func gen_mandatory_monster_deck(depth):
	return gen_mandatory_deck("Actor", depth)

func gen_item_deck(depth, budget):
	return gen_deck("Item", depth, budget)

func gen_mandatory_item_deck(depth):
	return gen_mandatory_deck("Item", depth)
