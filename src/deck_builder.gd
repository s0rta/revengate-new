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

func gen_monsters_deck(depth, budget):
	var deck = Deck.new()
	for child in get_children():
		if child is Actor:
			assert(child.spawn_cost != 0, "Can only produce decks when spawn_cost is configured")
			deck.add_card(child, budget/child.spawn_cost)
		if child is CardRule:
			if child.min_depth != -1 and depth < child.min_depth:
				continue
			if child.max_depth != -1 and depth > child.max_depth:
				continue
			# TODO: see if any of the other predicated apply
			for sub_child in child.get_children():
				if sub_child is Actor:
					assert(sub_child.spawn_cost != 0, "Can only produce decks when spawn_cost is configured")
					deck.add_card(sub_child, budget/sub_child.spawn_cost)
	
	deck.normalize()
	return deck

func gen_items_deck(depth, budget):
	# TODO: factor out the loop logic that's the same with monsters
	var deck = Deck.new()
	for child in get_children():
		if child is Item:
			assert(child.spawn_cost != 0, "Can only produce decks when spawn_cost is configured")
			deck.add_card(child, budget/child.spawn_cost)
	deck.normalize()
	return deck
