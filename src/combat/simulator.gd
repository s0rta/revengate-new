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

const NB_SIMS_PER_RUN = 500
const MAX_SIM_TURNS = 50
const RUN_ALL_STAGES = false  # sim the first board and all the challengers in $ExtraStages
const SHOW_ANIMS = false

# whether to let Godot start the sims in between rendering frames, gives better profiling stats
const ASYNC_MODE = false

signal sims_done  # sims completed for one stage (see RUN_ALL_STAGES)

var sim_running := false
var gladiator = null  # the actor who's fate tells us when the simulation is done
var challengers_health_full:int
var sim_board:RevBoard

var remaining_sims:int
var nb_turns:Array[int]  # array of number of turns each simulation lasted
var nb_hits:Dictionary  # actor->int
var nb_misses:Dictionary  # actor->int

# Results->int for all sims from the Gladiator's point of view
var results:Dictionary

# Results->[pct1, ...]
var gladiator_health_left:Dictionary
var challengers_health_left:Dictionary

var start_time:int

func _ready():
	for actor in get_actors():
		_make_duelist(actor)
		
	if RUN_ALL_STAGES:
		run_stages()
	else:
		run_sims()

func _input(event):
	if event.is_action_pressed("ui_accept"):
		run_sims()
	if event.is_action_pressed("right"):
		advance_stage()

func _process(_delta):
	if ASYNC_MODE:
		if not sim_running and remaining_sims >= 0:
			remaining_sims -= 1
			start_sim()
			if remaining_sims == 0:
				emit_signal("sims_done")

func _mk_res_store(default=[]):
	var clone = func (val):
		if val is int:
			return val
		else:
			return val.duplicate()
	return {Results.VICTORY:clone.call(default), 
			Results.DEFEAT:clone.call(default), 
			Results.DRAW:clone.call(default)}

func run_stages():
	run_sims()
	while $ExtraStages.get_child_count():
		advance_stage()
		run_sims()
		
func run_sims():
	remaining_sims = NB_SIMS_PER_RUN
	start_time = Time.get_ticks_msec()
	nb_turns = []
	nb_hits = {}
	nb_misses = {}
	results = _mk_res_store(0)
	gladiator_health_left = _mk_res_store()
	challengers_health_left = _mk_res_store()
	
	var names = $Board.get_actors().map(func (actor): return actor.name)
	print("Starting a batch of %d sims for %s..." % [remaining_sims, ", ".join(names)])
	
	if ASYNC_MODE:
		await sims_done
	else:
		while remaining_sims > 0:
			remaining_sims -= 1
			start_sim()
	summarize_sims()

func start_sim():
	sim_running = true
	if sim_board:
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
	if SHOW_ANIMS:
		Tender.hero = gladiator
	$TurnQueue.run()
	sim_running = false

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

func _make_duelist(actor):
	var strat = Dueling.new(actor, 1.0)
	actor.add_child(strat)

func advance_stage():
	## Line up the next contender(s) to fight againts the gladiator
	var next_stage = $ExtraStages.get_child(0)
	if next_stage == null:
		print("No stage to advance to.")
		return

	var old_actors = $Board.get_actors()
	var gladiator = old_actors.pop_front()
	for actor in old_actors:
		actor.reparent(self)
		actor.queue_free()
	
	var new_actors = []
	if next_stage is Actor:
		new_actors.append(next_stage)
	else:
		for child in next_stage.get_children():
			new_actors.append(child)
		next_stage.reparent(self)
		next_stage.queue_free()
	
	var gladiator_coord = gladiator.get_cell_coord()
	var builder = BoardBuilder.new($Board)
	var index = $Board.make_index()
	for actor in new_actors:
		_make_duelist(actor)
		builder.place(actor, false, gladiator_coord, true, null, index)
	
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
	
	if remaining_sims > 0:
		if not $TurnQueue.is_stopped():
			await $TurnQueue.done
		$TurnQueue.reset()

func summarize_sims():
	var elapsed = (Time.get_ticks_msec() - start_time) / 1000.0
	var nb_sims = Utils.sum(results.values())
	var all_turns = Utils.sum(nb_turns)
	print("Ran %d sims in %0.2f seconds (%0.2f turn/s)" % [nb_sims, elapsed, all_turns/elapsed])
	print("Median encouter lasted %d turns" % Utils.median(nb_turns))
	print("Victory: %0.2f%%" % (100.0*results[Results.VICTORY]/nb_sims))
	summarize_gladiator_health(Results.VICTORY)
	print("Defeat: %0.2f%%" % (100.0*results[Results.DEFEAT]/nb_sims))
	summarize_challengers_health(Results.DEFEAT)
	print("Draw: %0.2f%%" % (100.0*results.get(Results.DRAW, 0)/nb_sims))
	summarize_gladiator_health(Results.DRAW)
	summarize_challengers_health(Results.DRAW)
	
	var names = nb_hits.keys()
	names.sort()
	for name in names:
		var total = nb_hits[name] + nb_misses.get(name, 0)
		var hit_rate = 100.0 * nb_hits[name] / total
		print("%s's hit rate: %0.2f%%" % [name, hit_rate])
	print()

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
	if gladiator == null or not gladiator.is_alive():
		finalize_sim(Results.DEFEAT)
	elif len(get_actors(true)) == 1:
		finalize_sim(Results.VICTORY)
		
func _on_turn_queue_turn_started(turn):
	if turn > MAX_SIM_TURNS:
		finalize_sim(Results.DRAW)
