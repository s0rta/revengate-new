# Copyright © 2022-2023 Yannick Gingras <ygingras@ygingras.net> and contributors

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
class_name Hero

const ENEMY_FACTIONS = [Factions.BEASTS]

func _ready():
	super()
	state = States.LISTENING

func _unhandled_input(event):
	if state != States.LISTENING:
		return
	var acted = false
	var move = null
	state = States.ACTING
		
	if event.is_action("act-on-cell"):
		var coord = RevBoard.canvas_to_board(event.position)
		print("Click at pos=%s, coord=%s" % [event.position, RevBoard.coord_str(coord)])
		
		if RevBoard.dist(get_cell_coord(), coord) == 1:
			var index = get_board().make_index()
			var other = index.actor_at(coord)
			if other and is_foe(other):
				attack(other)
				acted = true
			elif index.is_free(coord):
				move_to(coord)
				acted = true
		else:
			travel_to(coord)
			return await act()
	elif event.is_action_pressed("follow-stairs"):
		var board = get_board()
		var coord = get_cell_coord()
		if board.is_connector(coord):
			$"/root/Main".switch_board_at(coord)
			acted = true
		else:
			print("No stair to follow here")
	elif Input.is_action_just_pressed("right"):
		move = V.i(1, 0)
	elif Input.is_action_just_pressed("left"):
		move = V.i(-1, 0)
	elif Input.is_action_just_pressed("up"):
		move = V.i(0, -1)
	elif Input.is_action_just_pressed("down"):
		move = V.i(0, 1)
		
	if move:
		ray.enabled = true
		ray.target_position = move * RevBoard.TILE_SIZE
		ray.force_raycast_update()
		if ray.is_colliding():
			var collider = ray.get_collider()
			if collider is Actor and is_foe(collider):
				attack(collider)
				acted = true
			else:
				print("Can't act in this direction: %s is in the way!" % collider)
		else:
			self.move_by(move)
			acted = true
	if acted:
		finalize_turn()
	else:
		state = States.LISTENING

func is_foe(other: Actor):
	return ENEMY_FACTIONS.has(other.faction)

func act():
	var strat = get_strategy()
	if strat:
		print("Hero turn automated by %s" % [strat])
		state = States.ACTING
		var result = strat.act()
		finalize_turn()
		return result
	else:
		state = States.LISTENING
		print("hero acting...")
		await self.turn_done
		
