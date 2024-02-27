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

## Try to go towards target
class_name Seeking extends Strategy

@export var target_tags: Array[String]
@export var resolution_range := Consts.CONVO_RANGE
@export var resolution_message := ""
@export var event_name: String
@export var cancel_event_name: String  # we stop seeking if this happened

## how many turns do we stay in place before moving on with our life
@export var post_resolution_turns := 5


var target: Actor
var met_target = false
var turn: int

func locate_target():
	# try to pick a new target
	var actors = me.get_board().get_actors(target_tags)
	actors.filter(func(actor): return actor.is_alive())
	if actors.is_empty():
		return
	target = Rand.choice(actors)

func refresh(turn_):
	turn = turn_
	if target == null:
		locate_target()

func is_expired() -> bool:
	if cancel_event_name and Tender.hero.mem.recall(cancel_event_name):
		return true
	return super()

func is_valid():
	return super() and target != null and target.is_alive() and not met_target
		
func act() -> bool:	
	# Go towards target, meet target when target reached
	var board = me.get_board()
	if board.dist(me, target) <= resolution_range:
		met_target = true
		if not resolution_message.is_empty():
			me.add_message(resolution_message, Consts.MessageLevels.WARNING)
		return resolve()
	else:
		return me.move_toward_actor(target)
	
func resolve():
	if ttl < 0:
		ttl = post_resolution_turns
	for mem in [me.mem, Tender.hero.mem]:
		mem.learn(event_name, turn, Memory.Importance.CRUCIAL)
	return true
