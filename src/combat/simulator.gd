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

const MAX_SIM_TURNS = 15
var gladiator = null  # the actor who's fate tells us when the simulation is done
var nb_hits = {}  # actor->int
var nb_misses = {}  # actor->int

func _ready():
	for actor in get_actors():
		if gladiator == null:
			gladiator = actor
		actor.died.connect(_on_actor_died)
		actor.hit.connect(_inc_hit.bind(actor))
		actor.missed.connect(_inc_miss.bind(actor))
	$TurnQueue.run()

func get_board():
	return $Board
	
func get_actors(alive:=false):
	var actors = $Board.find_children("", "Actor", false, false)
	if alive:
		actors = actors.filter(func (actor): return actor.is_alive())
	return actors

func finalize_sim():
	$TurnQueue.shutdown()
	print("Sim is over after %s turns" % $TurnQueue.turn)
	print("hits: %s" % [nb_hits])
	print("misses: %s" % [nb_misses])

func _inc_hit(actor, _victim, _damage):
	nb_hits[actor] = nb_hits.get(actor, 0) + 1

func _inc_miss(actor, _victim):
	nb_misses[actor] = nb_misses.get(actor, 0) + 1

func _on_actor_died(_coord, _tags):
	print("Someone died...")
	if gladiator == null or not gladiator.is_alive():
		finalize_sim()
	elif len(get_actors(true)) == 1:
		finalize_sim()
		
func _on_turn_queue_turn_started(turn):
	if turn > MAX_SIM_TURNS:
		finalize_sim()
