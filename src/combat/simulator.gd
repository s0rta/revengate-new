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

## Run staged combats and record summaries of what happened
class_name Simulator extends Node2D

enum Results {VICTORY, DEFEAT, DRAW}

const MAX_SIM_TURNS = 30
var remaining_sims = 100

var gladiator = null  # the actor who's fate tells us when the simulation is done
var challengers_health_full:int
var nb_hits = {}  # actor->int
var nb_misses = {}  # actor->int
var sim_board:RevBoard

# Results->int for all sims from the Gladiator's point of view
var results = {Results.VICTORY:0, Results.DEFEAT:0, Results.DRAW:0}

# Results->[pct1, ...]
var gladiator_health_left = {Results.VICTORY:[], Results.DEFEAT:[], Results.DRAW:[]}
var challengers_health_left = {Results.VICTORY:[], Results.DEFEAT:[], Results.DRAW:[]}

var nb_turns = []  # array of number of turns each simulation lasted


@onready var start_time = Time.get_ticks_msec()

func _ready():
	run_sims()

func run_sims():
	while remaining_sims > 0:
		remaining_sims -= 1
		start_sim()
	summarize_sims()

func start_sim():
	if sim_board:
		sim_board.reparent($/root)
		sim_board.queue_free()
	sim_board = $Board.duplicate()
	add_child(sim_board)
	challengers_health_full = 0
	gladiator = null
	for actor in get_actors():
		if gladiator == null:
			gladiator = actor
		else:
			challengers_health_full += actor.health_full
		actor.died.connect(_on_actor_died)
		actor.hit.connect(_inc_hit.bind(actor))
		actor.missed.connect(_inc_miss.bind(actor))
	$TurnQueue.run()

func get_board():
	if sim_board:
		return sim_board
	else:
		return $Board
	
func get_actors(alive:=false):
	var actors = get_board().find_children("", "Actor", false, false)
	if alive:
		actors = actors.filter(func (actor): return actor.is_alive())
	return actors

func finalize_sim(result:Results):
	$TurnQueue.shutdown()
	var turn = $TurnQueue.turn
	results[result] = results.get(result, 0) + 1
	nb_turns.append(turn)
	gladiator_health_left[result].append(100.0 * gladiator.health / gladiator.health_full)
	
	var health_tot = 0
	for actor in get_actors(true):
		if actor != gladiator:
			health_tot += actor.health
	challengers_health_left[result].append(100.0 * health_tot / challengers_health_full)
	
	print("Sim is over after %s turns" % turn)
	print("hits: %s" % [nb_hits])
	print("misses: %s" % [nb_misses])
	print("Results: %s" % [results])

	if remaining_sims > 0:
		if not $TurnQueue.is_stopped():
			await $TurnQueue.done
		$TurnQueue.reset()

func summarize_sims():
	var elapsed = (Time.get_ticks_msec() - start_time) / 1000.0
	var total = 0
	for val in results.values():
		total += val
	print("Ran %d sims in %0.2f seconds" % [total, elapsed])
	print("Median encouter lasted %d turns" % Utils.median(nb_turns))
	print("Victory: %0.2f%%" % (100.0*results[Results.VICTORY]/total))
	summarize_gladiator_health(Results.VICTORY)
	print("Defeat: %0.2f%%" % (100.0*results[Results.DEFEAT]/total))
	summarize_challengers_health(Results.DEFEAT)
	print("Draw: %0.2f%%" % (100.0*results.get(Results.DRAW, 0)/total))
	summarize_gladiator_health(Results.DRAW)
	summarize_challengers_health(Results.DRAW)

func summarize_gladiator_health(result:Results):
	# Print the median gladiator health for encounters that ended in `result`
	# Do nothing if no encouters ended in `result`
	if not gladiator_health_left[result].is_empty():
		var median_health = Utils.median(gladiator_health_left[result])
		print("  median gladiator health: %0.2f%%" % median_health)

func summarize_challengers_health(result:Results):
	# like summarize_gladiator_health(), but for challengers
	if not challengers_health_left[result].is_empty():
		var median_health = Utils.median(challengers_health_left[result])
		print("  median challengers health: %0.2f%%" % median_health)

func _inc_hit(victim, damage, actor):
	nb_hits[actor.name] = nb_hits.get(actor.name, 0) + 1

func _inc_miss(_victim, actor):
	nb_misses[actor.name] = nb_misses.get(actor.name, 0) + 1

func _on_actor_died(_coord, _tags):
	print("Someone died...")
	if gladiator == null or not gladiator.is_alive():
		finalize_sim(Results.DEFEAT)
	elif len(get_actors(true)) == 1:
		finalize_sim(Results.VICTORY)
		
func _on_turn_queue_turn_started(turn):
	if turn > MAX_SIM_TURNS:
		finalize_sim(Results.DRAW)
