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
signal resumed  # processing is ready to restart after being paused

var state = States.STOPPED

var turn := 0
var turn_is_valid := true

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

func pause():
	state = States.PAUSED
	invalidate_turn()
	
func is_paused():
	return state == States.PAUSED
	
func resume():
	assert(state == States.PAUSED)
	state = States.PROCESSING
	emit_signal("resumed")

func run():
	var actors: Array
	turn_is_valid = true
	state = States.PROCESSING
	while state == States.PROCESSING:
		print("=== Start of turn %d ===" % turn)
		actors = get_actors()
		print("playing actors: %s " % [actors])
		# 1st pass: tell all in-play objects about the start of the turn
		get_board().start_turn(turn)
			
		# 2rd pass: actions
		for actor in actors:
			if not turn_is_valid:
				break
			if actor == null or not actor.is_alive():  # died from conditions
				continue
			if actor.is_animating():  # still moving from previous turn, let's wait a bit
				await actor.anims_done
			actor.act()
			if not actor.is_idle():
				print("waiting for %s..." % actor)
				await actor.turn_done
				print("done with %s!" % actor)
			if turn_is_valid and actor.is_animating():
				await get_tree().create_timer(ACTING_DELAY).timeout
		if state == States.PAUSED:
			await resumed
		turn += 1
		turn_is_valid = true
	state = States.STOPPED
