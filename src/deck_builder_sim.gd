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

extends Node

const max_sim_depth = 12
const nb_sims = 1000

@export var base_spawn_budget := 0

var start_time: int
var all_keys: Dictionary

func _ready():
	#find deck builders
	var deck_builders = find_children("", "DeckBuilder", false, false)
	
	# int -> [all_sims_counter, sim_counters]
	var per_depth_stats = {}
	all_keys = {}
	
	var sim_counter
	
	start_time = Time.get_ticks_msec()
	for i in nb_sims:
		var builder = deck_builders[0].duplicate() as DeckBuilder
		
		for depth in range(1, max_sim_depth + 1):
			var budget = spawn_budget(depth, Dungeon.MONSTER_MULTIPLIER)
			
			sim_counter = {}
			if not per_depth_stats.has(depth):
				per_depth_stats[depth] = [{}, []]
			
			var all_sims_counter = per_depth_stats[depth][0]
			var sim_counters = per_depth_stats[depth][1]
			
			var deck = builder.gen_mandatory_deck("Actor", depth, Consts.LOC_INVALID)
			budget = draw_and_tally(deck, budget, all_sims_counter, sim_counter, true)
			deck = builder.gen_prob_deck("Actor", depth, Consts.LOC_INVALID, budget)
			budget = draw_and_tally(deck, budget, all_sims_counter, sim_counter, true)
				
			sim_counters.append(sim_counter)
	
	var elapsed = (Time.get_ticks_msec() - start_time) / 1000.0
	
	print("Time elapsed: %.1fs | Decks per second: %.2f d/s"%[elapsed, (nb_sims * max_sim_depth * 2) / elapsed])
	for depth in range(1, max_sim_depth + 1):
		print("Summary of depth %d"% [depth])
		var all_sims_counter = per_depth_stats[depth][0]
		var sim_counters = per_depth_stats[depth][1]
		
		sumarize_sims(all_sims_counter, sim_counters, all_keys.keys())
	

func draw_and_tally(deck, budget, all_sims_counter, sim_counter, strict_budget):
	## Get all the cards we can from `deck` and record what cards were drawn.
	## `strict_budget`: stop drawing as soon as we went over `budget`.
	while not deck.is_empty():
		if strict_budget and budget <= 0:
			break
		var card = deck.draw()
		var key = [card.caption.to_lower(), card.get_short_desc()] 
		all_keys[key] = true
		budget -= card.spawn_cost
		
		inc_occ(all_sims_counter, key)
		inc_occ(sim_counter, key)
	return budget


func sumarize_sims(all_sims_counter, sim_counters, all_keys):
	var total_cards = Utils.sum(all_sims_counter.values())
	all_keys.sort()
	var k_nums = [10, 50, 90]
	
	for key in all_keys:
		var occ = []
		for counter in sim_counters:
			occ.append(counter.get(key, 0))

		if all_sims_counter.get(key, false):
			var percentiles = Utils.percentile_breakdown(occ, k_nums)

			var summary = ""
			summary += "%27s: %5.2f%% |"% [key[1], (1.0 * all_sims_counter.get(key, 0) / total_cards) * 100]
			for i in len(k_nums):
				summary += " p%d: %d"%[k_nums[i], percentiles[i]]

			print(summary)

	print()

func inc_occ(counter, key):
	if not counter.has(key):
		counter[key] = 1
	else:
		counter[key] += 1

func spawn_budget(depth, budget_multiplier):
	return max(0, (base_spawn_budget + depth)*budget_multiplier)
