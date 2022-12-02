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

@tool
extends Actor

const ENEMY_FACTIONS = [Factions.BEASTS]

func _ready():
	super()
	state = States.LISTENING

func _input(_event):
	pass

func _unhandled_input(event):
	# TODO: mark as handled
	var move = null
	if state != States.LISTENING:
		return
	
	if Input.is_action_just_pressed("right"):
		move = V.i(1, 0)
	if Input.is_action_just_pressed("left"):
		move = V.i(-1, 0)
	if Input.is_action_just_pressed("up"):
		move = V.i(0, -1)
	if Input.is_action_just_pressed("down"):
		move = V.i(0, 1)
		
	if move:
		ray.enabled = true
		ray.target_position = move * RevBoard.TILE_SIZE
		ray.force_raycast_update()
		if ray.is_colliding():
			print("collision towards %s" % move)
			return
		else:
			print("no colision at %s" % ray.target_position)
		state = States.ACTING
		var anim = self.move_by(move)
		await anim.finished
		print("anim finished")
		finalize_turn()

func is_foe(other: Actor):
	return ENEMY_FACTIONS.has(other.faction)

func act():
	state = States.LISTENING
	print("hero acting...")
	await self.turn_done
		
