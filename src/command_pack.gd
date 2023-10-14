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

var _cmd_classes = []  # all sub-classes of Command must be added to this list

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

	func refresh(index_:RevBoard.BoardIndex):
		index = index_

	func is_valid_for(coord:Vector2i):
		assert(false, "Not implemented")

	func is_valid_for_hero_at(coord:Vector2i):
		return false  # sub-classes must override this to enable the HUD version of this command
		
	func run(coord:Vector2i) -> bool:
		assert(false, "Not implemented")
		return false

	func run_at_hero(coord:Vector2i) -> bool:
		# TODO: we might as well get the hero coord from the Tender and receive no args
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
		var attack_range = Tender.hero.get_max_weapon_range()
		var board = Tender.hero.get_board()
		if not board.is_on_board(coord):
			return false
		var hero_coord = Tender.hero.get_cell_coord()
		var dist = board.dist(hero_coord, coord)
		return dist <= attack_range and index.actor_at(coord)
		
	func run(coord:Vector2i) -> bool:
		var victim = index.actor_at(coord)
		await Tender.hero.attack(victim)
		return true

class QuickAttack extends Command:
	var nearby_foe = null
	var attack_range:int

	func _init(index_=null):
		is_action = true
		caption = "QuickAttack"
		super(index_)

	func _get_prior_victims():
		## Return an array of actors we've attacked previously
		var facts = Tender.hero.mem.recall_all("attacked", Tender.hero.current_turn)
		var victims = {}
		for fact in facts:
			if not victims.has(fact.foe):
				victims[fact.foe] = true
		return victims.keys()

	func is_valid_for_hero_at(coord:Vector2i):
		var board = Tender.hero.get_board()
		var hero = Tender.hero as Actor
		attack_range = hero.get_max_weapon_range()
		var actors = index.get_actors_in_sight(hero.get_cell_coord(), attack_range)
		actors.shuffle()
		var victims = _get_prior_victims()
		for actor in actors:
			if hero.is_foe(actor) or actor in victims:
				nearby_foe = actor
				return true
		return false
		
	func run_at_hero(coord:Vector2i) -> bool:
		var board = Tender.hero.get_board()
		var foe = null
		var fact = Tender.hero.mem.recall("attacked")
		if (fact and fact.foe != null and fact.foe.is_alive()
				and board.dist(Tender.hero, fact.foe) <= attack_range):
			foe = fact.foe
		else:
			foe = nearby_foe
		Tender.hero.attack(foe)
		return true

class Talk extends Command:
	func _init(index_=null):
		is_action = true
		caption = "Talk"
		super(index_)

	func is_valid_for(coord:Vector2i):
		var board = Tender.hero.get_board()
		if not board.is_on_board(coord):
			return false
		var hero_coord = Tender.hero.get_cell_coord()
		var dist = board.dist(hero_coord, coord)
		# TODO: it would make sense to have conversations further apart
		var other = index.actor_at(coord)
		return dist <= Consts.CONVO_RANGE and other and other.get_conversation()
		
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
		var messages = []
		var actor = index.actor_at(coord)
		if actor and not actor.is_unexposed():
			Tender.hud.actor_details_screen.fill_with(actor)
			Tender.hud.actor_details_screen.popup()
			await Tender.hud.actor_details_screen.closed
			
		Tender.viewport.flash_coord_selection(coord)

		# only one of Actor or Item message will show
		var board = Tender.hero.get_board()
		var here_str = "at %s" % board.coord_str(coord) if Utils.is_debug() else "here"

		if Tender.hero.perceives(coord):
			var vibes = index.vibes_at(coord)
			for vibe in vibes:
				var desc = vibe.get_short_desc()
				if desc:
					messages.append("There is %s %s" % [desc, here_str])
		var item = index.top_item_at(coord)
		if item != null:
			messages.append("There is a %s %s" % [item.get_short_desc(), here_str])
		elif board.is_on_board(coord):
			var terrain = board.get_cell_terrain(coord)
			if Utils.is_debug():
				messages.append("There is a %s tile %s" % [terrain, here_str])
			else:
				messages.append("This is a %s tile" % [terrain])
		
		if messages.is_empty():
			messages.append("There is nothing %s" % here_str)

		for msg in messages:
			Tender.hero.add_message(msg)
		
		return false

class TravelTo extends Command:
	func _init(index_=null):
		is_action = false
		caption = "Travel To"
		super(index_)

	func is_valid_for(coord:Vector2i):
		var board = Tender.hero.get_board()
		if not board.is_on_board(coord):
			return false
		var hero_coord = Tender.hero.get_cell_coord()
		return index.is_free(coord) and board.path(hero_coord, coord)
		
	func run(coord:Vector2i) -> bool:
		if Tender.hero.travel_to(coord):
			return Tender.hero.act()
		else:
			# didn't work, probably because the path is blocked
			return false
		
class DoorHandler extends Command:
	var door_at = null
	var target_terrain:String
	
	func _is_valid_door(coord):
		var board = Tender.hero.get_board() as RevBoard
		return board.get_cell_terrain(coord) == target_terrain

	func is_valid_for(coord:Vector2i):
		var board = Tender.hero.get_board() as RevBoard
		if board.dist(coord, Tender.hero) != 1:
			return false
		return _is_valid_door(coord)

	func is_valid_for_hero_at(coord:Vector2i):
		var board = Tender.hero.get_board() as RevBoard
		for c in board.adjacents(coord, false):
			if _is_valid_door(c):
				door_at = c
				return true
		return false
		
	func run(coord:Vector2i) -> bool:
		var board = Tender.hero.get_board() as RevBoard
		board.toggle_door(coord)
		return true

	func run_at_hero(coord:Vector2i):
		return run(door_at)	

class CloseDoor extends DoorHandler:
	func _init(index_=null):
		is_action = true
		caption = "Close door"
		target_terrain = "door-open"
		super(index_)

	func _is_valid_door(coord):
		return super(coord) and index.is_free(coord)

class OpenDoor extends DoorHandler:
	var key:Item
	func _init(index_=null):
		is_action = true
		caption = "Open door"
		target_terrain = "door-closed"
		super(index_)

	func _is_valid_door(coord):
		if not super(coord):
			return false
		var board = Tender.hero.get_board()
		if board.is_locked(coord): 
			var cell_rec = board.get_cell_rec(coord, "locked")
			var keys = Tender.hero.get_items([cell_rec.key])
			if not keys.is_empty():
				key = Rand.choice(keys)
			else:
				return false
		return true

	func run(coord:Vector2i) -> bool:
		var board = Tender.hero.get_board() as RevBoard
		if board.is_locked(coord):
			board.unlock(coord, key)
		super(coord)
		return true
		
func _ready():
	_cmd_classes = [Attack, Talk, TravelTo, Inspect, CloseDoor, OpenDoor]

func commands_for(coord, hero_pov:=false, index=null):
	## Return a list of valid coordinates for `coord`
	# TODO: option to make the list from the point of view of the hero
	
	if index == null:
		index = Tender.hero.get_board().make_index()
	var commands = []
	for cls in _cmd_classes:
		var cmd = cls.new(index)
		if (hero_pov and cmd.is_valid_for_hero_at(coord)) \
			or (not hero_pov and cmd.is_valid_for(coord)):
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
