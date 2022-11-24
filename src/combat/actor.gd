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
signal turn_done

enum States {
	IDLE,
	LISTENING,
	ACTING,
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
@export var resistance: Weapon.DamageFamily  # at most one!

var state = States.IDLE
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
	var scene = get_tree()
	var anim := scene.create_tween()
	var cpos = RevBoard.board_to_canvas(board_coord)
	anim.tween_property(self, "position", cpos, .2)
	dest = board_coord
	anim.finished.connect(reset_dest, CONNECT_ONE_SHOT)
	return anim

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
	var anim := get_tree().create_tween()
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

func play_sound(node_name, weapon):
	## Play the most specific sound for "node_name": either from the weapon or from the actor node.
	## Do nothing if we can't the requested sound
	var sound
	for node in [weapon, self]:
		sound = node.get_node(node_name)
		if sound:
			sound.play()

func update_health(hp_delta: int):
	## Update our health and animate the event.
	## Return the animation.
	health += hp_delta
	var label = $DamageLabel.duplicate()
	add_child(label)
	label.text = "%d" % -hp_delta
	label.visible = true
	var anim := get_tree().create_tween()
	var offset = Vector2(RevBoard.TILE_SIZE/4, -RevBoard.TILE_SIZE/2)
	anim.tween_property(label, "position", label.position+offset, .5)
	var anim2 := get_tree().create_tween()
	anim2.pause()
	# start the fadeout about half way through
	anim2.tween_property(label, "modulate", Color(0, 0, 0, 0), .25)
	var timer := get_tree().create_timer(.25)
	timer.timeout.connect(anim2.play)
	anim.finished.connect(label.queue_free, CONNECT_ONE_SHOT)
	return anim

func is_alive():
	return health > 0
	
func is_dead():
	return not is_alive()

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
	if resistance == null:
		return 1.0
	elif weapon.damage_family == resistance:
		return RESIST_MULT
	else:
		return 1.0
	
func attack(foe):
	## A full multi-strike attack on foe.
	## Sentiment and range are not checked, the caller is responsible for 
	## performing those tests.
	for weapon in get_weapons():
		if foe.is_alive():
			strike(foe, weapon)
		
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
	# FIXME: apply damage
	return anim_hit(foe, weapon, damage)	
