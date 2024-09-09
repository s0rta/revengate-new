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

## Run staged combats and record summaries of what happened
class_name Simulator extends Node2D

# Terminology
# - sim: all the turns of a combat encounter until last party standing (gladiator or challengers)
# - stage: many sims (~1000) all with the same gladiator and challengers
# - run: one or more stages, based on RUN_ALL_STAGES
# - gladiator: like the `hero` in the game, but controlled by the simulator rather than the player
# - challengers: everyone else, all challengers are allied against the gladiator

# To run, add two or more actors on $Board, the first one will be the gladiator for all stages.
# Optionally: add more actors as chidren of $ExtraStages,
#   stages can with multiple challengers must be a Node with actors as direct children.
# Then press F6 (run scene).

# TODO: fix placement of stage-0 if anyone is inside a wall or on top of one another

enum Results {VICTORY, DEFEAT, DRAW}

const NB_SIMS_PER_RUN = 1000
const MAX_SIM_TURNS = 50
const RUN_ALL_STAGES = true  # sim the first board and all the challengers in $ExtraStages
const DEF_START_COORD = Vector2i(2, 2)  # default starting coord for the gladiator if not already placed in a valid cell

# Whether to let Godot start the sims in between rendering frames, gives better
# profiling stats, but runs slower
const ASYNC_MODE = true
const SIM_PER_FRAME = 10  # only applies to ASYNC_MODE

signal sims_done  # sims completed for one stage (see RUN_ALL_STAGES)

var sim_running := false
var gladiator = null  # the actor who's fate tells us when the simulation is done
var challengers_health_full:int
var sim_board:RevBoard

var remaining_sims := -1  # setting this auto-starts the runner in async mode
var nb_turns:Array[int]  # array of number of turns each simulation lasted
var nb_hits:Dictionary  # actor->int
var nb_misses:Dictionary  # actor->int

# Results->int for all sims from the Gladiator's point of view
var results:Dictionary

# Results->[pct1, ...]
var gladiator_health_left:Dictionary
var challengers_health_left:Dictionary

var start_time:int
var combat_msec:int

func _ready():
	var actors = get_actors(true)
	for actor in actors:
		_make_duelist(actor)
	ensure_valid_placement()
	
	if ASYNC_MODE or not RUN_ALL_STAGES:
		run_sims()
	else:
		run_stages()

func _input(event):
	if event.is_action_pressed("ui_accept"):
		run_sims()
	if event.is_action_pressed("right"):
		advance_stage()

func _process(_delta):
	if ASYNC_MODE:
		# FIXME: should not start until we confirm that the setup is finished
		for i in SIM_PER_FRAME:
			if not sim_running and remaining_sims > 0:
				remaining_sims -= 1
				start_sim()
				if remaining_sims == 0:
					sims_done.emit()
					return
			elif RUN_ALL_STAGES and not sim_running and remaining_sims <= 0:
				if advance_stage():
					run_sims.call_deferred()
					return
				else:
					print("Done!")
					get_tree().quit()
					break

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
	start_time = Time.get_ticks_msec()
	combat_msec = 0
	nb_turns = []
	nb_hits = {}
	nb_misses = {}
	results = _mk_res_store(0)
	gladiator_health_left = _mk_res_store()
	challengers_health_left = _mk_res_store()

	var names = $Board.get_actors().map(func (actor): return actor.name)
	print("Starting a batch of %d sims for %s..." % [NB_SIMS_PER_RUN, ", ".join(names)])

	remaining_sims = NB_SIMS_PER_RUN
	if ASYNC_MODE:
		await sims_done
		print("Finished sims for %s" % [", ".join(names)])
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

	# FIXME: as off Godot 4.2.1, we can't do this from _ready() and the simulator only works
	#   in aync-mode for now.
	add_child(sim_board)

	challengers_health_full = 0
	gladiator = null
	var actors = get_actors(true)
	for actor in actors:
		actor.spawn()
		if gladiator == null:
			gladiator = actor
		else:
			challengers_health_full += actor.health_full
		if not actor.died.is_connected(_on_actor_died):
			actor.died.connect(_on_actor_died)
			actor.hit.connect(_inc_hit.bind(actor))
			actor.missed.connect(_inc_miss.bind(actor))

	assert(gladiator != null, "Could not find a gladiator on sim #%d" % [NB_SIMS_PER_RUN - remaining_sims])

	var combat_start = Time.get_ticks_msec()
	$TurnQueue.run()
	assert($TurnQueue.is_stopped())
	combat_msec += Time.get_ticks_msec() - combat_start

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
	var strat = Dueling.new(actor, 0.99)
	actor.add_child(strat)

func advance_stage() -> bool:
	## Line up the next contender(s) to fight againts the gladiator
	## Return false when all stage have been executed
	if not $ExtraStages.get_child_count():
		print("No stage to advance to.")
		return false
	var next_stage = $ExtraStages.get_child(0)

	var old_actors = $Board.get_actors()
	# GC everyone except the gladiator
	for actor in old_actors.slice(1):
		destroy_node(actor)

	var new_actors = []
	if next_stage is Actor:
		new_actors.append(next_stage)
	else:
		for child in next_stage.get_children():
			new_actors.append(child)
		destroy_node(next_stage)

	var desc_func = func (actor): return actor.get_short_desc()
	print("Advancing stage to: %s" % [new_actors.map(desc_func)])

	for actor in new_actors:
		actor.reparent($Board)
	ensure_valid_placement()
	for actor in new_actors:
		_make_duelist(actor)
		actor.owner = null  # maybe builder.place() should not change the owner?
	return true

func ensure_valid_placement(arms_reach=true):
	## Make sure all the actors are in a valid location on the board
	## `actors`: Actors to reposition, the first one is considered the gladiator
	## `arms_reach`: no movement will be needed to start fighting, if possible
	var actors = get_actors()
	var board:RevBoard = get_board()

	# First, make sure the gladiator is in a valid spot, then more everyone next to them.
	var builder = BoardBuilder.new(board)
	var gladiator_coord:Vector2i = actors[0].get_cell_coord()
	var index = board.make_index()
	if not board.is_walkable(gladiator_coord):
		var old_owner = actors[0].owner
		gladiator_coord = builder.place(actors[0], false, Consts.COORD_INVALID, true, null, index)
		actors[0].owner = old_owner
	for actor in actors.slice(1):
		var good_place = true
		if arms_reach and board.dist(gladiator_coord, actor) != 1:
			good_place = false
		if not board.is_walkable(actor.get_cell_coord()):
			good_place = false
		if not good_place:
			var old_owner = actor.owner
			builder.place(actor, false, gladiator_coord, true, null, index)
			actor.owner = old_owner

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
	var combat_sec = combat_msec / 1000.0
	var nb_sims = Utils.sum(results.values())
	var all_turns = Utils.sum(nb_turns)
	print("Ran %d sims in %0.2f seconds (%0.2f turn/s)" % [nb_sims, elapsed, all_turns/elapsed])
	print("Combat time:  %0.2f seconds (%0.2f turn/s)" % [combat_sec, all_turns/combat_sec])
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

func destroy_node(node:Node):
	node.reparent(self)
	node.owner = null
	node.queue_free()
