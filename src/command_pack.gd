# Copyright © 2023–2024 Yannick Gingras <ygingras@ygingras.net> and contributors

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
	var ui_action = null
	var is_default := false  # is this command what you'd get from a single tap?
	var is_cheat := false
	var is_debug := false
	var caption: String
	var auto_display := true  # show a button for this command whenever it's valid
	var index: RevBoard.BoardIndex

	func _init(index_=null):
		if index_ != null:
			index = index_
		else:
			index = Tender.hero.get_board().make_index()

	func get_caption():
		if is_default:
			return caption + " (👆)"
		else:
			return caption

	func refresh(index_:RevBoard.BoardIndex):
		index = index_

	func is_valid_for(coord:Vector2i):
		assert(false, "Not implemented")

	func is_valid_for_hero_at(coord:Vector2i):
		return false  # sub-classes must override this to enable the HUD version of this command
		
	func run(coord:Vector2i) -> bool:
		## Run the command, return if that counted as a turn action.
		assert(false, "Not implemented")
		return false

	func run_at_hero(coord:Vector2i) -> bool:
		## Run the command, return if that counted as a turn action.
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
		if dist > attack_range or not index.has_los(hero_coord, coord):
			return false
		var other = index.actor_at(coord)
		if other == null or other.is_dead() or not Tender.hero.perceives(other):
			return false
		is_default = (other != null 
						and other != Tender.hero 
						and Tender.hero.is_foe(other))
		return true
		
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
		actors = actors.filter(func(actor): return actor.is_alive())
		actors.shuffle()
		var victims = _get_prior_victims()
		for actor in actors:
			if hero.is_foe(actor) or actor.actor_id in victims:
				nearby_foe = actor
				return true
		return false
		
	func run_at_hero(coord:Vector2i) -> bool:
		var board = Tender.hero.get_board()
		var foe = nearby_foe
		
		# try to go again on the last actor we attacked if possible
		var fact = Tender.hero.mem.recall("attacked")
		if fact:
			var last_foe = index.actor_by_id(fact.foe)
			if (last_foe != null and last_foe.is_alive() 
					and board.dist(Tender.hero, last_foe) <= attack_range 
					and index.has_los(Tender.hero, last_foe)):
				foe = last_foe

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
		is_default = other != null and not Tender.hero.is_foe(other)		
		return (dist <= Consts.CONVO_RANGE 
				and other
				and other.is_alive()
				and other.get_conversation() 
				and Tender.hero.perceives(other))
		
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

class SkipTurn extends Command:
	func _init(index_=null):
		is_action = true
		caption = "Skip Turn"
		auto_display = false
		super(index_)

	func is_valid_for(coord:Vector2i):
		return coord == Tender.hero.get_cell_coord()

	func is_valid_for_hero_at(_coord:Vector2i) -> bool:
		return true

	func run(coord:Vector2i) -> bool:
		return true

	func run_at_hero(coord:Vector2i) -> bool:
		return true

class Rest extends Command:
	const PERCEPTION_MOD = -45
	
	func _init(index_=null):
		is_action = true
		caption = "Rest"
		super(index_)

	func is_valid_for(coord:Vector2i) -> bool:
		return coord == Tender.hero.get_cell_coord()
		
	func is_valid_for_hero_at(_coord:Vector2i) -> bool:
		return false  # it's valid, but we lie to make the buttons less spammy

	func run(coord:Vector2i) -> bool:
		var target_health = _find_target_health()
		var ttl = _find_ttl(target_health)
		var strat = Resting.new(Tender.hero, 1.0, ttl, target_health)
		var mods = StatsModifiers.new()
		mods.perception = PERCEPTION_MOD
		strat.add_child(mods)
		Tender.hero.add_strategy(strat)
		Tender.hero.add_message("You close your eyes and meditate for a while...")
		return true
	
	func run_at_hero(coord:Vector2i) -> bool:
		return run(coord)
		
	func _find_target_health() -> int:
		var me = Tender.hero
		var hratio = me.get_health_ratio()
		if hratio >= 1.0:
			return -1
		elif hratio < .65:
			return .80 * me.health_full
		else:
			return min((hratio + .15) * me.health_full, me.health_full)

	func _find_ttl(target_health:int):
		const min_ttl := 50
		var me:Actor = Tender.hero
		if target_health < 0:
			return min_ttl
		else:
			var hdelta = target_health - me.health
			return max(int(hdelta / me.healing_prob * 1.5), min_ttl)

class Inspect extends Command:
	func _init(index_=null):
		is_action = false
		caption = "Inspect"
		super(index_)

	func is_valid_for(coord:Vector2i):
		return true
		
	func run(coord:Vector2i) -> bool:
		var board = Tender.hero.get_board()
		board.clear_highlights()
		var messages = []
		var actor:Actor = index.actor_at(coord)
		if actor and not actor.is_unexposed(index):
			Tender.hud.actor_details_screen.show_actor(actor)
			await Tender.hud.actor_details_screen.closed
			
		# only one of Actor or Item message will show
		board.highlight_cells([coord])
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
		is_action = true
		caption = "Travel To"
		super(index_)

	func is_valid_for(coord:Vector2i):
		var board = Tender.hero.get_board()
		if not board.is_on_board(coord):
			return false
		var hero_coord = Tender.hero.get_cell_coord()
		# FIXME: should use board.path_perceived()
		return index.is_free(coord) and board.path(hero_coord, coord)
		
	func run(coord:Vector2i) -> bool:
		if Tender.hero.travel_to(coord, index):
			Tender.hero.act()
			return true
		else:
			# didn't work, probably because the path is blocked
			return false

class GetCloser extends Command:
	var other
	var path
	var dist
	func _init(index_=null):
		is_action = true
		caption = "Get Closer"
		super(index_)

	func is_valid_for(coord:Vector2i):
		other = index.actor_at(coord)
		if other == null or other.is_unexposed(index):
			return false
		var board = Tender.hero.get_board()
		var hero_coord = Tender.hero.get_cell_coord()
		dist = board.dist(hero_coord, coord)
		if dist <= 1:
			return false
		path = board.path_perceived_strict(hero_coord, coord, Tender.hero, false, -1, index)
		return path != null
		
	func run(coord:Vector2i) -> bool:
		if dist > Tender.hero.get_max_action_range(other):
			var strat = Approaching.new(other, path, Tender.hero, 0.9)
			Tender.hero.add_strategy(strat)
			await Tender.hero.act()
		else:
			Tender.hero.move_toward_actor(other)
		return true

class DumpDevCheat extends Command:
	func _init(index_=null):
		is_action = false
		ui_action = "cheat-inspect-at"
		is_debug = true
		caption = "Debug Dump"
		super(index_)

	func is_valid_for(coord:Vector2i):
		return true
	
	func is_valid_for_hero_at(coord:Vector2i):
		return true
	
	func _ddump_at(coord):
		# TODO: move most of this to board.ddump_cell()
		var coord_str = RevBoard.coord_str(coord)
		print("Data at %s:" % coord_str)
		var board: RevBoard = Tender.hero.get_board()
		print("  Board.is_in_rect(%s): %s" % [coord_str, board.is_on_board(coord)])
		board.ddump_cell(coord)
		var actor = index.actor_at(coord)
		if actor:
			actor.ddump()
		var item = index.top_item_at(coord)
		if item:
			item.ddump()

	func run(coord:Vector2i) -> bool:
		_ddump_at(coord)
		return false

	func _start_ddump():
		var surveyor = Tender.hud.get_gesture_surveyor()
		var res = await surveyor.start_capture_coord("select position...")
		if res.success:
			_ddump_at(res.coord)

	func run_at_hero(coord:Vector2i) -> bool:
		_start_ddump()
		return false

class Cheat extends Command:
	func _init(index_=null):
		is_action = false
		is_cheat = true
		super(index_)

	func inc_nb_cheats():
		Tender.nb_cheats += 1

class TeleportCheat extends Cheat:
	func _init(index_=null):
		ui_action = "cheat-teleport-to"
		caption = "Teleport"
		super(index_)

	func is_valid_for(coord:Vector2i):
		return true
	
	func is_valid_for_hero_at(coord:Vector2i):
		return true
	
	func run(coord:Vector2i) -> bool:
		inc_nb_cheats()
		Tender.hero.place(coord, true)
		return false

	func _start_teleport():
		var surveyor = Tender.hud.get_gesture_surveyor()
		var res = await surveyor.start_capture_coord("Teleport where?")
		if res.success:
			inc_nb_cheats()
			Tender.hero.place(res.coord, true)

	func run_at_hero(coord:Vector2i) -> bool:
		_start_teleport()
		return false

class RegenCheat extends Cheat:
	func _init(index_=null):
		caption = "Regen"
		super(index_)

	func is_valid_for(coord:Vector2i):
		return false
	
	func is_valid_for_hero_at(coord:Vector2i):
		return true
	
	func run_at_hero(coord:Vector2i) -> bool:
		inc_nb_cheats()
		Tender.hero.health += Tender.hero.health_full / 2
		Tender.hero.health_changed.emit(Tender.hero.health)
		return false

class VictoryCheat extends Cheat:
	func _init(index_=null):
		caption = "End Chapter"
		super(index_)

	func is_valid_for(coord:Vector2i):
		return false
	
	func is_valid_for_hero_at(coord:Vector2i):
		return true
	
	func run_at_hero(coord:Vector2i) -> bool:
		inc_nb_cheats()
		var game_over = false
		if Tender.quest.tag == "quest-face-retznac":
			game_over = true
		Tender.hero.end_chapter.emit(true, game_over)
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

	func run_at_hero(coord:Vector2i) -> bool:
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
	_cmd_classes = [Attack, Talk, TravelTo, GetCloser, Inspect, CloseDoor, OpenDoor, 
					SkipTurn, Rest,
					DumpDevCheat, TeleportCheat, RegenCheat, VictoryCheat]

func get_commands(names:Array[String]) -> Dictionary:
	## Return a {name:instance} mapping from command captions.
	## Raise an assertion error if any of the names does not correspond to a command.
	## If more than one command use the same caption, the first one in the registry is returned.
	# TODO: it would be more robust to go by class name rather than caption, but that 
	#   does not seem possible as of Godot 4.2.1
	var dict = {}
	var has_match : bool
	for name in names:
		has_match = false
		for cls in _cmd_classes:
			var cmd = cls.new()
			if cmd.caption == name:
				has_match = true
				dict[name] = cmd
				break
		assert(has_match, "Can't find a command labeled %s" % name)
	return dict

func commands_for(coord, hero_pov:=false, auto_display:=true, index=null):
	## Return a list of valid coordinates for `coord`
	## `auto_display`: only return auto_display commands
	var is_debug = Utils.is_debug()
	var allow_cheats = Tabulator.load().allow_cheats
	if index == null:
		index = Tender.hero.get_board().make_index()
	
	var commands = []
	for cls in _cmd_classes:
		var cmd = cls.new(index)
		if not is_debug and cmd.is_cheat and not allow_cheats:
			continue
		if not is_debug and cmd.is_debug:
			continue
		if auto_display and not cmd.auto_display:
			continue
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
