# Copyright © 2022 Yannick Gingras <ygingras@ygingras.net> and contributors

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
enum States {STOPPED, PROCESSING}
var state = States.STOPPED

var turn = 0

func _ready():
	await run()

func find_actors():
	var actors = []
	var scene = get_parent()
	if scene == null:
		return []
	for node in scene.find_children("", "Actor"):
		if node.is_alive():
			actors.append(node)
	return actors
	
func run():
	var actors: Array
	state = States.PROCESSING
	while state == States.PROCESSING:
		print("=== Start of turn %d ===" % turn)
		actors = find_actors()
		print(actors)
		for actor in actors:
			actor.act()
			if actor.is_animating():
				await get_tree().create_timer(ACTING_DELAY).timeout
		for actor in actors:
			if actor.is_animating():
				print("Anims are active for %s..." % actor)
				await actor.anims_done
				print("Anims done for %s!" % actor)
			if actor.state != Actor.States.IDLE:
				print("waiting for %s..." % actor)
				await actor.turn_done
				print("done with %s!" % actor)
		turn += 1
	
