# Copyright © 2022-2024 Yannick Gingras <ygingras@ygingras.net> and contributors

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

# not emitted directly, the VictoryProbe decides when this emits
signal end_chapter(victory:bool, game_over:bool)

var _fog_anim = null  # the last tween that touched the FogLight size

func _ready():
	super()
	state = States.LISTENING
	Utils.adjust_lights_settings(self)

func _unhandled_input(event):
	if state != States.LISTENING:
		return
	if event is InputEventMouseMotion:
		return
	var acted = false  # TODO: set the `has_acted` member directly
	var move = null
	state = States.ACTING

	var board = get_board()
	var index = board.make_index()
	if event.is_action_pressed("act-on-cell"):
		var coord = RevBoard.canvas_to_board(event.position)
		print("Click at pos=%s, coord=%s" % [event.position, RevBoard.coord_str(coord)])

		var other = index.actor_at(coord)
		if other == self:
			# tapping on yourself doesn't do anything (yet)
			get_viewport().set_input_as_handled()
			state = States.LISTENING
			return
		elif other and not perceives(other):
			other = null
		var click_dist = RevBoard.dist(get_cell_coord(), coord)

		var attack_cmd = CommandPack.Attack.new(index)
		if attack_cmd.is_valid_for(coord) and attack_cmd.is_default:
			acted = await attack_cmd.run(coord)
		elif other and not is_foe(other) and click_dist <= Consts.CONVO_RANGE:
			if other.get_conversation():
				acted = await $"/root/Main".commands.talk(coord)
			else:
				get_board().add_message(self,
										"%s has nothing to tell you." % other.caption,
										Consts.MessageLevels.INFO,
										["msg:story"])
				acted = true
		elif other and not other.is_unexposed():
			# `acted` will be set by the Command if one is invoked
			$"/root/Main".show_context_menu_for(coord)
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
	elif event.is_action_pressed("show-inventory"):
		acted = await $"/root/Main".show_inventory_screen()
	elif event.is_action_pressed("follow-stairs"):
		var coord = get_cell_coord()
		if board.is_connector(coord):
			$"/root/Main".switch_board_at(coord)
			acted = true
		else:
			print("No stair to follow here")
	elif Input.is_action_pressed("right"):
		move = V.i(1, 0)
	elif Input.is_action_pressed("left"):
		move = V.i(-1, 0)
	elif Input.is_action_pressed("up"):
		move = V.i(0, -1)
	elif Input.is_action_pressed("down"):
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
		has_acted = true
		get_viewport().set_input_as_handled()
		finalize_turn()
	else:
		# NOT calling finalize_turn() to let the player provide more input during this turn
		state = States.LISTENING

func _dissipate():
	pass  # the hero sticks around so we can disect him/her for the end-of-game stats

func start_turn(turn_number:int):
	super(turn_number)
	scale_fog_light(get_perception_ranges().sight)

func scale_fog_light(nb_cells):
	## Adjust the size of the FogLight to light `nb_cells` passed the hero in all
	## cardinal directions.
	## The light is circular and will therefore cover fewer cells along diagonals.
	if _fog_anim != null and _fog_anim.is_running():
		_fog_anim.kill()
	var light_width = $FogLight.texture.get_width()
	var scale = 2.0 * (nb_cells + 0.5) * RevBoard.TILE_SIZE / light_width
	_fog_anim = get_tree().create_tween()
	_fog_anim.tween_property($FogLight, "texture_scale", scale, 0.35)

func act() -> void:
	has_acted = false
	var board = get_board()
	refresh_strategies()
	var strat = get_strategy()
	if strat:
		# The turn queue is supposed to await on anims_done before leting us play the next turn
		assert(not is_animating())

		print("Hero turn automated by %s" % [strat])
		state = States.ACTING
		has_acted = strat.act()
		# pass the control to the drawing thread to make sure our action is shown
		await get_tree().create_timer(0.0001).timeout
		finalize_turn()
	else:
		board.clear_highlights(RevBoard.LAYER_HIGHLIGHTS_LONG)
		state = States.LISTENING
		print("player acting...")
		var index = board.make_index()
		board.update_all_actor_shrouding(index)
		# _unhandled_input() or the selected Command must set has_acted and call finalize_turn()
		await self.turn_done
	board.clear_highlights()
