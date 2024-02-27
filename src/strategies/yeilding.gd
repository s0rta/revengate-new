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

## Submit to an attacker after taking a beating
class_name Yeilding extends Strategy

@export var fact_name: String
@export_range(0.0, 1.0) var yeild_health_percentage = 0.3 

## how many turns do we stay pleading before moving with our life
@export var post_yeild_turns := 5

var attacker_id: int
var turn: int
var has_yeilded = false

func refresh(turn_):
	turn = turn_

func is_valid():
	var health = (1.0 * me.health / me.health_full)
	if health <= yeild_health_percentage:
		var fact = me.mem.recall('was_attacked')
		if fact != null:
			has_yeilded = true
			attacker_id = fact.by
	return super() and has_yeilded
		
func act() -> bool:	
	# reset self-defense
	me.forgive(Tender.hero)
	Tender.hero.forgive(me)

	# Record that we have yeilded
	if not me.mem.recall(fact_name, turn, ):
		for mem in [me.mem, Tender.hero.mem]:
			mem.learn(fact_name, turn, Memory.Importance.CRUCIAL, {"attacker": attacker_id})
	var board = me.get_board()
	me.add_message("%s throws their arms in the air, saying 'I give up!'" % me.get_short_desc(),
					Consts.MessageLevels.WARNING)
	if ttl < 0:
		ttl = post_yeild_turns
	return true
