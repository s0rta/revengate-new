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

func _ready():
	state = States.LISTENING

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

		var other = index.actor_at(coord)
		if other and not perceives(other) or other == self:
			other = null
		var click_dist = RevBoard.dist(get_cell_coord(), coord)
		

		if other and is_foe(other) and click_dist <= get_max_weapon_range():
			attack(other)
			acted = true
		elif other and not is_foe(other) and click_dist <= Consts.CONVO_RANGE:
			if other.get_conversation():
				acted = await $"/root/Main".commands.talk(coord)
			else:
				get_board().add_message(self, "%s has nothing to tell you." % other.caption)
				acted = true
		elif other and not other.is_unexposed():
			acted = await $"/root/Main".show_context_menu_for(coord)
		else:
			# no one there
			if index.is_free(coord) and click_dist == 1:
				move_to(coord)
				acted = true
			elif board.is_walkable(coord):
				if (other == null or not perceives(other, index)) and travel_to(coord, index):
					# if the destination at least seems unoccupied, we start travelling there
					return await act()
	elif event.is_action_pressed("context-menu"):
		var coord = RevBoard.canvas_to_board(event.position)
		acted = await $"/root/Main".show_context_menu_for(coord)
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
		if board.is_on_board(dest) and index.is_free(dest):
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

func _dissipate():
	pass  # the hero sticks around so we can disect him/her for the end-of-game stats

func highlight_options():
	## Put highlight markers where one-tap actions are available
	var board = get_board()
	
	# FIXME: this pre-clearing is not needed if we figuere out what prevents turn_done
	# from firing when there is a conversation
	board.clear_highlights()
	
	var index = board.make_index() as RevBoard.BoardIndex
	var friend_coords = []
	var foe_coords = []
	
	var cmd = CommandPack.Talk.new(index)
	for actor in index.get_actors():
		var there = actor.get_cell_coord()
		if cmd.is_valid_for(there) and cmd.is_default:
			friend_coords.append(there)
			
	cmd = CommandPack.Attack.new(index)
	for actor in index.get_actors():
		var there = actor.get_cell_coord()
		if cmd.is_valid_for(there) and cmd.is_default:
			foe_coords.append(there)
	board.paint_cells(friend_coords, "highlight-friend", board.LAYER_HIGHLIGHTS)
	board.paint_cells(foe_coords, "highlight-foe", board.LAYER_HIGHLIGHTS)
	if not turn_done.is_connected(board.clear_highlights):
		turn_done.connect(board.clear_highlights, CONNECT_ONE_SHOT)

func act():
	refresh_strategies()
	var strat = get_strategy()
	if strat:
		# The turn queue is supposed to await on anims_done before leting us play the next turn
		assert(not is_animating())

		print("Hero turn automated by %s" % [strat])
		state = States.ACTING
		var acted = strat.act()
		finalize_turn()
		return acted
	else:
		state = States.LISTENING
		print("player acting...")
		highlight_options()
		await self.turn_done
		# TODO: it would make sense to let the input handlers tell us if something 
		#   actually happened.
		return true
