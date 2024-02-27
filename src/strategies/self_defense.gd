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

## Opportunistically fight back after being attacked.
class_name SelfDefense extends Strategy

var attacker_id = null
var attacker = null

func refresh(turn):
	var fact = me.mem.recall_any(["was_attacked", "was_targeted"])
	if fact != null:
		# TODO: give up if foe is too far or long enough has passed since the attack
		#   the fact will expire in memory, but that fells rather slow
		attacker_id = fact.by
	else:
		attacker_id = null

func is_valid():
	if not super():
		return false

	if not attacker_id:
		return false
	else:
		var index = me.get_board().make_index()
		attacker = index.actor_by_id(attacker_id)
		return attacker != null and attacker.is_alive()

func act() -> bool:
	var board = me.get_board()
	if board.dist(me, attacker) == 1:
		await me.attack(attacker)
		return true  # it costs you your turn to attack whether you land a hit or not
	else:
		return me.move_toward_actor(attacker)
