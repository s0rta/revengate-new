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

@icon("res://src/strategies/strat.svg")

## Base class for strategies to automate the actions of an actor.
class_name Strategy extends Node



@export_range(0, 1) var priority := 0.0  # in 0..1
@export var ttl := -1  # turns till expiration of the strategy if >=0, infinite if negative
@export var cancellable := false  

var me: Actor  # the actor being controlled by this strategy
var is_cancelled := false

func _init(actor=null, priority_=null, ttl_=null):
	if actor and actor is Actor:
		me = actor
	if priority_ != null:
		priority = priority_
	if ttl_ != null: 
		ttl = ttl_

func _ready():
	# try to auto detect the actor that this strategy is attached to
	if not me:
		var parent = get_parent()
		if parent is Actor:
			me = parent
	assert(me, "Strategy must be connected to an Actor")
		
func _dissipate():
	## do some cleanup, then disappear
	if me:
		me.emit_signal("strategy_expired")
	queue_free()

func start_new_turn():
	## check if this strategy has expired, do the cleanup if so
	if ttl > 0:
		ttl -= 1
	if is_expired() and me:
		_dissipate()

func refresh(turn):
	## Update the internal states that would influence predicates like is_valid() and is_expired().
	## This will only be called exactly once per turn, before invoking any of the predicates.
	## Make this cheap. If priority has to change, it should happen here.
	pass  # nothing to do by default; sub-classes are most likely more interesting than that.

func is_valid() -> bool:
	## Return if the strategy is valid for the current turn
	## This is called at most once. Between refresh() and this, this one should be the most 
	## expensive of the two.
	return not is_expired() and not is_cancelled and ttl != 0
	
func is_expired() -> bool:
	## Return whether the strategy has expired. 
	## An expired stratedy can't become valid again and will eventually be deleted.
	return is_cancelled or ttl is int and ttl == 0

func cancel():
	## Cancel this strategy: won't be valid moving forward, but the action for this 
	## turn still goes on if it's already in progress.
	assert(cancellable, "This strategy is not cancellable!")
	is_cancelled = true

func act() -> bool:
	## Try to do the action for the turn. 
	## Return if the undertaken action costed a turn (most deliberate actions do,
	## regardless of success).
	## This method must be overloaded by sub-classes.
	assert(false, "act() must be re-implemented by subclasses")
	return false

func find_hero():
	## Return a reference to the Hero if it can be found.
	## There might not be a reference to the Hero if it just died or if we are running 
	## a simulation without any Hero.
	var board = me.get_parent()
	var hero = Tender.hero
	if hero != null and hero.is_alive() and hero.get_parent() == board:
		return hero
	else:
		return null

func add_hero_message(text:String, 
				level:Consts.MessageLevels=Consts.MessageLevels.INFO, 
				tags:Array[String]=[]):
	## Add a message if `me` is the hero.
	if me == Tender.hero:
		me.add_message(text, level, tags)

func _path_next(path):
	## Return the next place to move along a path
	var here = me.get_cell_coord()
	for step in path:
		if step != here:
			return step
	return null

func highlight_path(path):
	## Display a cell highlight on each steps of a path
	if not Consts.DEBUG_PATHS and me != Tender.hero:
		return
		
	var board:RevBoard = me.get_board()
	var terrain = "highlight-info"
	if me != Tender.hero:
		terrain = "highlight-warning"
	board.highlight_cells(path, terrain)
