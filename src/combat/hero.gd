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
class_name Hero extends Actor

const ENEMY_FACTIONS = [Factions.BEASTS]

func _ready():
	state = States.LISTENING
	was_attacked.connect(_add_attack_msg)

func _add_attack_msg(attacker):
	add_message("Hero was attacked by %s" % attacker.name)

func _unhandled_input(event):
	if state != States.LISTENING:
		return
	var acted = false
	var move = null
	state = States.ACTING
	
	var board = get_board()
	var index = board.make_index()
	if event.is_action("act-on-cell"):
		var coord = RevBoard.canvas_to_board(event.position)
		print("Click at pos=%s, coord=%s" % [event.position, RevBoard.coord_str(coord)])
		
		if RevBoard.dist(get_cell_coord(), coord) == 1:
			var other = index.actor_at(coord)
			if other and is_foe(other):
				attack(other)
				acted = true
			elif index.is_free(coord):
				move_to(coord)
				acted = true
		elif board.is_on_board(coord) and index.is_free(coord) and travel_to(coord):
			return await act()
	elif event.is_action_pressed("loot-here"):
		var item = index.top_item_at(get_cell_coord())
		if item:
			pick_item(item)
			acted = true
	elif event.is_action_pressed("show-inventory"):
		acted = await $"/root/Main".show_inventory_screen()
	elif event.is_action_pressed("follow-stairs"):
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
		var dest = get_cell_coord() + move
		if index.is_free(dest):
			self.move_by(move)
			acted = true
		else:
			var actor = index.actor_at(dest)
			if actor and is_foe(actor):
				attack(actor)
				acted = true
			elif actor:
				print("Can't act in this direction: %s is in the way!" % actor)
			else:
				print("Can't move to %s" % board.coord_str(dest))

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
		
