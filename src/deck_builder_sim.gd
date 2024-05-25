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

## A Monte Carlo Simulator to see what the typical board furnishing is like at 
## different depths.
extends Node

# Terminology 
# - sim: one set of decks fully drawn to budget from min_depth to max_depth
# - stage: many sims (~1000) with the same one refercence deck builder and dungeon params (start_depth and budget curves)
# - run: one or more stages (only single is currently implemented)
# - counter: {card_key:int} mapping, may be aggregated at arbitrary levels

# To run, set a DeckBuilder as the first child and press F6 (run scene)

const max_sim_depth = 12
const nb_sims = 1000

@export var base_spawn_budget := 0

func _ready():
	var start_time:int = Time.get_ticks_msec()

	var deck_builders = find_children("", "DeckBuilder", false, false)
	var ref_deck_builder = deck_builders[0]
	print("Starting a multi-depth simulation for %s" % ref_deck_builder)

	var contexts = []
	for card_type in ["Actor", "Item", "Vibe"]:
		contexts.append(sim_stage_for_card_type(ref_deck_builder, card_type))

	var elapsed = (Time.get_ticks_msec() - start_time) / 1000.0	
	var nb_decks := 0.0
	for depth in range(1, max_sim_depth + 1):
		print("Summary of depth %d"% [depth])
		for context in contexts:
			sumarize_depth(depth, context)
			nb_decks += context.nb_decks
	print("Time elapsed: %.1fs | Decks per second: %.2f d/s"%[elapsed, nb_decks / elapsed])

func sim_stage_for_card_type(ref_deck_builder, card_type) -> Dictionary:
	## run a whole simulation stage for a given card type, return the stage context
	var sim_counter:Dictionary
	var all_keys := {}  # used as a set, all the card keys seen during this stage
		
	## stage: one counter for each depth, reused for all the sims at that depth during the stage
	## sims: an array of counters for each depth. Each sim appends a new counter
	var stage_context = {"stage": {}, "sims": {}, "nb_decks": 0}
	var run_tally
	for i in nb_sims:
		run_tally = Tally.new()
		var builder = ref_deck_builder.duplicate() as DeckBuilder
		builder.run_tally = run_tally
		
		for depth in range(1, max_sim_depth + 1):
			if not stage_context.stage.has(depth):
				stage_context.stage[depth] = {}
				stage_context.sims[depth] = []
			sim_counter = {}

			var budget = spawn_budget(depth, Dungeon.BUDGET_MULTIPLIERS[card_type])			
			var depth_counters = [stage_context.stage[depth], sim_counter]
			
			var deck = builder.gen_mandatory_deck(card_type, depth, Consts.LOC_INVALID)
			budget = draw_and_tally(deck, budget, depth_counters, true)
			deck = builder.gen_prob_deck(card_type, depth, Consts.LOC_INVALID, budget)
			budget = draw_and_tally(deck, budget, depth_counters, true)			
			stage_context.nb_decks += 2
			
			for key in sim_counter:
				all_keys[key] = true
			stage_context.sims[depth].append(sim_counter)
	
	stage_context.ordered_keys = all_keys.keys()
	stage_context.ordered_keys.sort()

	return stage_context

func card_key(card):
	## covert a card into something that hashes well and groups instances of the same card together
	## The natural order of card keys also makes sense for the end of stage report.
	return [card.caption.to_lower(), card.get_short_desc()] 
	
func fmt_key(card_key):
	## Convert a card key into something that looks good in the end of stage report
	return "%33s" % [card_key[1]]

func draw_and_tally(deck, budget, counters:Array, strict_budget):
	## Get all the cards we can from `deck` and record what cards were drawn.
	## `strict_budget`: stop drawing as soon as we went over `budget`.
	while not deck.is_empty():
		if strict_budget and budget <= 0:
			break
		var card = deck.draw()
		var key = card_key(card)
		for cnt in counters:
			inc_occ(cnt, key)
		budget -= card.spawn_cost
	return budget

func sumarize_depth(depth:int, stage_context:Dictionary):
	var stage_counter = stage_context.stage[depth]
	var total_cards = Utils.sum(stage_counter.values())
	var k_nums = [10, 50, 90]
	
	for key in stage_context.ordered_keys:
		var occ = []
		for counter in stage_context.sims[depth]:
			occ.append(counter.get(key, 0))

		if stage_counter.get(key, false):
			var percentiles = Utils.percentile_breakdown(occ, k_nums)

			var pct = 100.0 * stage_counter.get(key, 0) / total_cards
			var summary = "%s: %5.2f%% |" % [fmt_key(key), pct]
			for i in len(k_nums):
				summary += " p%d: %d"%[k_nums[i], percentiles[i]]
			print(summary)
		else:
			# we have not seen this card at that depth in any of the sims during this stage
			pass
	print()

func inc_occ(counter, key):
	if not counter.has(key):
		counter[key] = 1
	else:
		counter[key] += 1

func spawn_budget(depth, budget_multiplier):
	# TODO: get this from the dungeon
	return max(0, (base_spawn_budget + depth)*budget_multiplier)
