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

extends Item

@export var fuse_nb_turns := 4

func _dissipate():
	blow_up()
	super()

func blow_up():
	if not is_unexposed():
		Tender.viewport.effect_at_coord("explosion_sfx", get_cell_coord())
	splash_damage()

func splash_damage():
	## Hurt everyone in the blast radius
	var board = get_board()
	var index = board.make_index()
	var center = get_cell_coord()
	for victim in index.get_actors_in_sight(center, 3, true):
		# TODO: Euclid dist would be better for this
		var dist = board.man_dist(center, victim.get_cell_coord())
		var damage = 5 - dist
		
		# damage could be negative since man_dist() is different that what radius is tested with
		if damage > 0:  
			# TODO: might look better with a slight delay on the effect	
			# TODO: use take into account the actor's resistance	
			victim.update_health(-damage)

func toggle():
	super()
	add_tag("lit")
	ttl = fuse_nb_turns
	switchable = false

func get_short_desc():
	var desc = super()
	if ttl > -1:
		return "%s blows up in %d turns" % [desc, ttl]
	return desc
