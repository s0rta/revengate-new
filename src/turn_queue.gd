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

const ACTING_DELAY = 0.1  # in seconds
enum States {STOPPED, PAUSED, PROCESSING, SHUTTING_DOWN}
signal paused  # all the in-fligh actions are done, not doing anything until resume is requested
signal resumed  # processing is ready to restart after being paused
signal done  # processing stopped
signal turn_started(turn:int)

@export var verbose := true

var state = States.STOPPED
var turn := 0
var turn_is_valid := true
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
		
func invalidate_turn(_arg=null):
	## Mark the current turn as impossible to complete, skip to the next turn as soon as possible.
	## Turns can become invalid for many reasons. For example if the Hero gets on a new level with 
	## a whole cast of actors, it does not make sense to finish the old turn with only actors from 
	## the previous level.
	turn_is_valid = false

func shutdown():
	## Stop processing turns as soon as possible. 
	## Typically the current actor will finish their turn before the shutdown begins.
	state = States.SHUTTING_DOWN
	invalidate_turn()

func pause(immediate=true):
	## Stop new actors from taking their turn. 
	## The current actor might still finish their turn if they have started.
	## The turn counter is not advanced.
	state = States.PAUSED
	if immediate and current_actor and not current_actor.is_idle():
		current_actor.cancel_action()
	invalidate_turn()
	
func is_paused():
	return state == States.PAUSED

func reset():
	## Bring the turn queue back to like it was at the start of the game
	assert(state == States.STOPPED, "A running TurnQueue must be shutdown before you can reset it.")
	turn = 0
	turn_is_valid = true
	
func resume():
	assert(state == States.PAUSED)
	state = States.PROCESSING
	emit_signal("resumed")

func is_stopped():
	return state == States.STOPPED

func run():
	var actors: Array
	turn_is_valid = true
	state = States.PROCESSING
	while state == States.PROCESSING:
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
			
		# 2rd pass: actions
		for actor in actors:
			if not turn_is_valid:
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
			if actor.is_animating():  # still moving from previous turn, let's wait a bit
				await actor.anims_done
			actor.act()
			if not actor.is_idle():
				if verbose:
					print("waiting for %s..." % actor)
				await actor.turn_done
				if verbose:
					print("done with %s!" % actor)
			if turn_is_valid and actor.is_animating():
				await get_tree().create_timer(ACTING_DELAY).timeout
		if state == States.PAUSED:
			print("TurnQueue is paused, not advancing turn")
			paused.emit()
			await resumed
		else:
			turn += 1
		turn_is_valid = true
	current_actor = null
	state = States.STOPPED
	emit_signal("done")
