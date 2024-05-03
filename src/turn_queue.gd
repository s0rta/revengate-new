# Copyright © 2022–2023 Yannick Gingras <ygingras@ygingras.net> and contributors

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

# headstart that an actor has to begin their animation before the next actor starts 
# moving, in seconds
const MAX_ACTING_DELAY = 0.1

enum States {STOPPED, PAUSED, PROCESSING, SHUTTING_DOWN}
signal paused  # all the in-fligh actions are done, not doing anything until resume is requested
signal resumed  # processing is ready to restart after being paused
signal done  # processing stopped
signal turn_started(turn:int)
signal turn_finished(turn:int)

@export var verbose := true

var state = States.STOPPED
var turn := 0
var process_actions := true
var advance_turn := true
var current_actor

# TODO: an explicit ref to Main would be cleaner
func get_board():
	var main = get_parent()
	if main == null:
		return null
	return main.get_board()

func get_actors():
	var actors = []
	var board = get_board()
	if board == null:
		return []
	for node in board.get_actors():
		if node.is_alive():
			actors.append(node)
	return actors

func skip_turn(immediate=true):
	## Skip to the next turn as soon as possible.
	## Turns can become invalid for many reasons. For example if the Hero gets on a new level with 
	## a whole cast of actors, it does not make sense to finish the old turn with only actors from 
	## the previous level.
	process_actions = false
	advance_turn = true
	if immediate and current_actor and not current_actor.is_idle():
		current_actor.cancel_action()
	
func abort_turn(immediate=true):
	## Stop new actors from taking their turn. The turn will the redone from the start.
	## This is useful for saving games at a known point after a turn has started.
	process_actions = false
	advance_turn = false
	if immediate and current_actor and not current_actor.is_idle():
		current_actor.cancel_action()

func shutdown(immediate:=false):
	## Stop processing turns as soon as possible. 
	## Typically the current actor will finish their turn before the shutdown begins.
	state = States.SHUTTING_DOWN
	skip_turn(immediate)

func pause(immediate=true):
	## Stop new actors from taking their turn. 
	## The current actor might still finish their turn if they have started.
	## The turn counter is not advanced.
	state = States.PAUSED
	abort_turn(immediate)	

func is_paused():
	return state == States.PAUSED

func reset():
	## Bring the turn queue back to like it was at the start of the game
	assert(state == States.STOPPED, "A running TurnQueue must be shutdown before you can reset it.")
	turn = 0
	
func resume():
	assert(state == States.PAUSED)
	state = States.PROCESSING
	emit_signal("resumed")

func is_running():
	return state == States.PROCESSING

func is_stopped():
	return state == States.STOPPED

func run():
	assert(is_stopped(), "This TurnQueue is already running in a different thread.")
	var actors: Array
	state = States.PROCESSING
	while state == States.PROCESSING:
		process_actions = true
		advance_turn = true
		current_actor = null
		if verbose:
			print("=== Start of turn %d ===" % turn)
		emit_signal("turn_started", turn)
		actors = get_actors()
		if verbose:
			print("playing actors: %s " % [actors])
		# 1st pass: tell all in-play objects about the start of the turn
		#   boards and actors know how to skip conditions for a turn they have already seen, 
		#   so restarting an in-progress turn (perhaps from restoring a saved game) is safe.
		get_board().start_turn(turn)
		
		var visible_actors = 0
		for actor in actors:
			if actor.is_alive() and not actor.is_unexposed():
				visible_actors += 1

		# 2rd pass: actions
		for actor in actors:
			if not process_actions:
				break
			if actor == null or not actor.is_alive():  # died from conditions
				continue
			if actor.acted_turn >= turn:
				# this actor has already played, the in-progress turn must have 
				# been restored and resumed.
				if verbose:
					print("skipping %s who has already acted this turn" % actor)
				continue
			current_actor = actor
			
			var start_wait = Time.get_ticks_msec()
			if actor.is_animating():  # still moving from previous turn, let's wait a bit
				await actor.anims_done
				var elapsed = (Time.get_ticks_msec() - start_wait) / 1000.0
				if verbose:
					print("Had to wait %s on %s before starting its action" % [elapsed, actor])
				
			var start_act = Time.get_ticks_msec()
			await actor.act()
			if not actor.is_idle():
				if verbose:
					print("waiting for %s..." % actor)
				await actor.turn_done

			if verbose:
				var elapsed = (Time.get_ticks_msec() - start_act) / 1000.0
				print("%s acted for %0.3f seconds" % [actor, elapsed])
			if process_actions and actor.is_animating():
				var delay = min(2.0 * MAX_ACTING_DELAY / visible_actors, MAX_ACTING_DELAY)
				await get_tree().create_timer(delay).timeout
		var last_turn = turn
		if advance_turn:
			turn += 1
		turn_finished.emit(last_turn)
		if state == States.PAUSED:
			print("TurnQueue is paused, not advancing turn")
			paused.emit()
			await resumed
	current_actor = null
	state = States.STOPPED
	done.emit()
