# Copyright © 2022 Yannick Gingras <ygingras@ygingras.net> and contributors

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
extends Area2D
class_name Actor

# the actor won't play again until the turn counter is incremented
signal turn_done  
# the actor is done moving, but it could move again during the current turn
signal anims_done  
# the actor was the victim of an attack
signal was_attacked(attacker)

enum States {
	IDLE,
	LISTENING,
	ACTING,
}

enum Factions {
	NONE,
	LUX_CO,
	BEASTS
}

# std. dev. for a normal distribution more or less contained in 0..100
const SIGMA := 12.5  
# average of the above distribution
const MU := 50  

# 50% less damage if you have a resistance
const RESIST_MULT := 0.5

# 35% more damage on a critical hit
const CRITICAL_MULT := 0.35

# core combat attributes
@export var health := 50
@export var strength := 50
@export var agility := 50
@export var intelligence := 50
@export var perception := 50
@export var resistance: Weapon.DamageFamily = 0  # at most one!

@export var faction := Factions.NONE

var state = States.IDLE
var nb_active_anims := 0
var ray := RayCast2D.new()
var dest  # keep track of where we are going while animations are running 

func _ready():
	ray.name = "Ray"
	add_child(ray)
	ray.collide_with_areas = true

func _get_configuration_warnings():
	var warnings = []
	if name != "Hero" and find_children("", "Strategy").is_empty():
		update_configuration_warnings()
		warnings.append("Actor's can't act without a strategy.")
	return warnings

func is_idle() -> bool:
	return state == States.IDLE

func is_acting() -> bool:
	return state == States.ACTING

func is_listening() -> bool:
	return state == States.LISTENING
	
func stop_listening():
	assert(is_listening())
	state = States.IDLE

func get_board():
	## Return the RevBoard this actor is playing on, return `null` is no board is currently active.
	# board is either the parent or the global board
	var parent = get_parent()
	if parent is RevBoard:
		return parent
	else:
		var main = $"/root/Main"
		if main:
			return main.get_board()
	return null

func _dec_active_anims():
	nb_active_anims = max(0, nb_active_anims - 1)
	if nb_active_anims == 0:
		emit_signal("anims_done")

func create_anim() -> Tween:
	## Return a Tween animation for this actor, register the anim as active.
	var anim = create_tween()
	nb_active_anims += 1
	anim.finished.connect(_dec_active_anims, CONNECT_ONE_SHOT)
	return anim

func is_animating():
	## Return whether the actor is currently performing an animation.
	return nb_active_anims > 0

func finalize_turn():
	state = States.IDLE
	emit_signal("turn_done")

func reset_dest():
	dest = null

func get_cell_coord():
	## Return the board position occupied by the actor.
	## If the actor is currently moving, return where it's expected to be at the
	## end of the turn.
	if dest != null:
		return dest
	else:
		return RevBoard.canvas_to_board(position)

func place(board_coord):
	## Place the actor at the specific coordinate without animations.
	## No tests are done to see if board_coord is a suitable location.
	if state == States.ACTING:
		await self.turn_done
	position = RevBoard.board_to_canvas(board_coord)

func move_by(cell_vect: Vector2i):
	## Move by the specified number of tiles from the current position. 
	## The move is animated, return the animation.
	var new_pos = RevBoard.canvas_to_board(position) + cell_vect
	return move_to(new_pos)
	
func move_to(board_coord):
	## Move to the specified board coordinate in number of tiles from the 
	## origin. 
	## The move is animated, return the animation.
	var anim := create_anim()
	var cpos = RevBoard.board_to_canvas(board_coord)
	anim.tween_property(self, "position", cpos, .2)
	dest = board_coord
	anim.finished.connect(reset_dest, CONNECT_ONE_SHOT)
	return anim

func travel_to(there):
	## Strat the multi-turn journey that takes us to `there`
	## Depending on where we are in the turn logic, the caller might need to call `stop_listening()` 
	## for the travelling strategy to kick in, otherwise, it will only be active on the next turn.
	var path = $"/root/Main/Board".path(get_cell_coord(), there)
	var strat = Traveling.new(there, path, self, 0.9)
	add_child(strat)

func get_strategy():
	## Return the best strategy for this turn or `null` if no strategy is currently valid.
	var pri_desc = func(a, b):
		return a.priority >= b.priority
	var strats = []
	# find_children() does not find dynamically created strategies for some reason
	for node in get_children():
		if node is Strategy and node.is_valid():
			strats.append(node)
	if strats.size(): 
		strats.sort_custom(pri_desc)
		return strats[0]
	else:
		return null

func _get_lunge_anim_cpos(foe):
	## Return the canvas coord where an attack animation should reach before starting the 
	## retreat animation.
	# going roughtly half a cell towards foe, no matter how far foe is
	var my_coord = get_cell_coord()
	var foe_coord = foe.get_cell_coord()
	var attack_vec = Vector2(foe_coord - my_coord)
	attack_vec = attack_vec.normalized()
	var anim_vec = 0.45 * attack_vec
	return position + anim_vec * RevBoard.TILE_SIZE
	
func _anim_lunge(foe):
	## Return the animation of lunging forward towards `foe` then retreaing.
	var anim_dest = _get_lunge_anim_cpos(foe)
	var old_cpos = position
	var anim := create_anim()
	anim.set_trans(anim.TRANS_SINE)
	anim.tween_property(self, "position", anim_dest, .15)
	anim.tween_property(self, "position", old_cpos, .2)
	return anim
	
func anim_miss(foe, weapon):
	## Animate a missed strike towards `foe`, return the animation object.
#	if foe.state == States.ACTING:
#		await foe.turn_done
	play_sound("MissSound", weapon)

	var anim = _anim_lunge(foe)
	return anim

func anim_hit(foe, weapon, damage):
	## Animate a success strike on `foe`, return the animation object.
#	if foe.state == States.ACTING:
#		await foe.turn_done
	print("hit %s for %s dmg" % [foe, damage])
	play_sound("HitSound", weapon)
	
	foe.update_health(-damage)
	var anim = _anim_lunge(foe)
	return anim

func play_sound(node_name, weapon=null):
	## Play the most specific sound for "node_name": either from the weapon or from the actor node.
	## Do nothing if we can't the requested sound
	var sound
	for node in [weapon, self]:
		if node:
			sound = node.get_node_or_null(node_name)
		if sound:
			sound.play()
			return

func update_health(hp_delta: int):
	## Update our health and animate the event.
	## Return the animation.
	health += hp_delta
	if hp_delta < 0:
		emit_signal("was_attacked", null)
		
	var label = $DamageLabel.duplicate()
	add_child(label)
	label.text = "%d" % -hp_delta
	label.visible = true
	var anim := create_anim()
	anim.finished.connect(label.queue_free, CONNECT_ONE_SHOT)
	var offset = Vector2(RevBoard.TILE_SIZE/4, -RevBoard.TILE_SIZE/2)
	anim.tween_property(label, "position", label.position+offset, .5)
	var anim2 := create_anim()
	anim2.pause()
	# start the fadeout about half way through
	anim2.tween_property(label, "modulate", Color(0, 0, 0, 0), .25)
	var timer := get_tree().create_timer(.25)
	timer.timeout.connect(anim2.play)
	if health <= 0:
		play_sound("DeathSound")
		# no need to add this one to anims since sub-tweens have the same signal as the root tween
		var anim3 = anim.parallel()  
		anim3.tween_property($Label, "modulate", Color(.8, 0, 0, .7), .1)
		anim3.tween_property($Label, "modulate", Color(0, 0, 0, 0), .4)
		anim3.finished.connect(self.queue_free, CONNECT_ONE_SHOT)
	return anim

func is_alive():
	return health > 0
	
func is_dead():
	return not is_alive()

func is_friend(other: Actor):
	## Return whether `self` has positive sentiment towards `other`
	return faction != Factions.NONE and faction == other.faction
	
func is_foe(other: Actor):
	## Return whether `self` has negative sentiment towards `other`
	return faction != Factions.LUX_CO and other.faction == Factions.LUX_CO
	
func is_impartial(other: Actor):
	## Return whether `self` has neutral sentiment towards `other`
	return !is_friend(other) and !is_foe(other)

func get_weapons():
	## Return all the active weapons for the current turn.
	## All active weapons are eligible for a strike during the turn.
	## Ex: a fast feline would return a bite and two claw weapons.
	return find_children("", "Weapon")
	
func get_evasion(weapon):
	## Return the evasion stat against a particular weapon. 
	return agility
	
func get_resist_mult(weapon):
	## Return a multiplier to attenuate `weapon`'s damage based on our resistances.
	## The multiplier is in [0..1], with 1 being full damage
	if !resistance:
		return 1.0
	elif weapon.damage_family == resistance:
		return RESIST_MULT
	else:
		return 1.0
	
func attack(foe):
	## A full multi-strike attack on foe.
	## Sentiment and range are not checked, the caller is responsible for 
	## performing those tests.
	
	# FIXME: if more than one strike, we need to wait to the first one to finish before 
	# we start the next one
	for weapon in get_weapons():
		if foe.is_alive():
			return strike(foe, weapon)
		
func strike(foe, weapon):
	## Strike foe with weapon. The strike could result in a miss. 
	## The result is immediately visible in the world.
	# combats works with two random rolls: to-hit then damage.
	
	var crit = false
	# to-hit	
	var roll = randfn(MU, SIGMA)
	if roll < foe.get_evasion(weapon):
		# Miss!
		return anim_miss(foe, weapon)
	
	if roll > MU + 2*SIGMA:
		crit = true

	# damage roll		
	var stat = strength  # TODO: will be intelligence for spells
	var damage = (1 + (stat - MU) / 100.0) * weapon.damage * randf()
	if crit:
		damage *= CRITICAL_MULT
	damage *= foe.get_resist_mult(weapon)
	damage = max(1, round(damage))
	return anim_hit(foe, weapon, damage)	
