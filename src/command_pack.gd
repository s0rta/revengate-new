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

## A container for player-triggered game commands.
class_name CommandPack extends Node

var _cmd_classes = []

## A game command
class Command extends RefCounted:
	var is_action: bool
	var caption: String
	var index: RevBoard.BoardIndex

	func _init(index_=null):
		if index_ != null:
			index = index_
		else:
			index = Tender.hero.get_board().make_index()

	func is_valid_for(coord:Vector2i):
		assert(false, "Not implemented")
		
	func run(coord:Vector2i) -> bool:
		assert(false, "Not implemented")
		return false

	func _to_string():
		return "<Command %s>" % caption

class Attack extends Command:
	func _init(index_=null):
		is_action = true
		caption = "Attack"
		super(index_)

	func is_valid_for(coord:Vector2i):
		var hero_coord = Tender.hero.get_cell_coord()
		var board = Tender.hero.get_board()
		var dist = board.dist(hero_coord, coord)
		return dist == 1 and index.actor_at(coord)
		
	func run(coord:Vector2i) -> bool:
		var victim = index.actor_at(coord)
		await Tender.hero.attack(victim)
		return true

class Talk extends Command:
	func _init(index_=null):
		is_action = true
		caption = "Talk"
		super(index_)

	func is_valid_for(coord:Vector2i):
		var hero_coord = Tender.hero.get_cell_coord()
		var board = Tender.hero.get_board()
		var dist = board.dist(hero_coord, coord)
		# TODO: it would make sense to have conversations further apart
		var other = index.actor_at(coord)
		return dist == 1 and other and other.get_conversation()
		
	func run(coord:Vector2i) -> bool:
		var other = index.actor_at(coord)
		var conversation = other.get_conversation()
		if conversation == null:
			Tender.hud.add_message("%s has nothing to say." % other.caption)
		Tender.hud.dialogue_pane.start(conversation.res, conversation.sect, other)
		await Tender.hud.dialogue_pane.hidden
		
		# FIXME: we never seem to receive this signal when called by hero directly
		print("The dia has been closed!")
		return true

class Inspect extends Command:
	func _init(index_=null):
		is_action = false
		caption = "Inspect"
		super(index_)

	func is_valid_for(coord:Vector2i):
		return true
		
	func run(coord:Vector2i) -> bool:
		var actor = index.actor_at(coord)
		if actor:
			Tender.hud.actor_details_screen.fill_with(actor)
			Tender.hud.actor_details_screen.popup()
			await Tender.hud.actor_details_screen.closed
			
		Tender.viewport.flash_coord_selection(coord)

		var board = Tender.hero.get_board()
		var here_str = "at %s" % board.coord_str(coord) if Utils.is_debug() else "here"
		var msg: String
		var item = index.top_item_at(coord)
		if item != null:
			msg = "There is a %s %s" % [item.get_short_desc(), here_str]
		elif board.is_on_board(coord):
			var terrain = board.get_cell_terrain(coord)
			if Utils.is_debug():
				msg = "There is a %s tile %s" % [terrain, here_str]
			else:
				msg = "This is a %s tile" % [terrain]
		else:
			msg = "There is nothing %s" % here_str
		Tender.hud.add_message(msg)
		return false

class TravelTo extends Command:
	func _init(index_=null):
		is_action = false
		caption = "Travel To"
		super(index_)

	func is_valid_for(coord:Vector2i):
		var board = Tender.hero.get_board()
		var hero_coord = Tender.hero.get_cell_coord()
		return index.is_free(coord) and board.path(hero_coord, coord)
		
	func run(coord:Vector2i) -> bool:
		if Tender.hero.travel_to(coord):
			return Tender.hero.act()
		else:
			# didn't work, probably because the path is blocked
			return false
		

func _ready():
	_cmd_classes = [Attack, Talk, TravelTo, Inspect]

func commands_for(coord, index=null):
	## Return a list of valid coordinates for `coord`
	if index == null:
		index = Tender.hero.get_board().make_index()
	var commands = []
	for cls in _cmd_classes:
		var cmd = cls.new(index)
		if cmd.is_valid_for(coord):
			commands.append(cmd)
	return commands

func inspect(coord):
	var cmd = Inspect.new()
	var acted = await cmd.run(coord)
	return acted

func talk(coord):
	var cmd = Talk.new()
	var acted = await cmd.run(coord)
	return acted
