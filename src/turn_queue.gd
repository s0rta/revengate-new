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
enum States {STOPPED, PROCESSING, SHUTTING_DOWN}
var state = States.STOPPED

var turn := 0
# var loop_is_active := false
var turn_is_valid := true

func get_actors():
	var actors = []
	var main = get_parent()
	if main == null:
		return []
	var board = main.get_board() as RevBoard
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
	
func run():
	var actors: Array
	turn_is_valid = true
	state = States.PROCESSING
	while state == States.PROCESSING:
		print("=== Start of turn %d ===" % turn)
		actors = get_actors()
		print("playing actors: %s " % [actors])
		# 1st pass: tell everyone about the start of the turn
		for actor in actors:
			actor.start_turn(turn)
		# 2nd pass: conditions
		for actor in actors:
			actor.activate_conditions()
		# 3rd pass: actions
		for actor in actors:
			if not turn_is_valid:
				break
			if actor == null or not actor.is_alive():  # died from conditions
				continue
			actor.act()
			if not actor.is_idle():
				print("waiting for %s..." % actor)
				await actor.turn_done
				print("done with %s!" % actor)
			if turn_is_valid and actor.is_animating():
				await get_tree().create_timer(ACTING_DELAY).timeout
		# 4th pass: finalize animations
		for actor in actors:
			if not turn_is_valid:
				break
			if actor == null:
				# this actor dissapeared before the end of the turn
				continue
			if actor.is_animating():
				print("Anims are active for %s..." % actor)
				await actor.anims_done
				print("Anims done for %s!" % actor)
		turn += 1
		turn_is_valid = true
	state = States.STOPPED
