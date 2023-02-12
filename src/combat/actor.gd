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

@tool
class_name Actor extends Area2D

# the actor won't play again until the turn counter is incremented
signal turn_done  
# the actor is done moving, but it could move again during the current turn
signal anims_done  
# the actor was the victim of an attack
signal was_attacked(attacker)
# health changed, either got better or worst
signal health_changed(new_health)
# the actor met their ultimate demise
signal died
# the actor moved to a new location on the current board
signal moved(from, to)
# the actor picked an item that used to be at `old_coord`
signal picked_item(old_coord)

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

# main visuals
@export_group("Visuals")
@export var char := "x"
@export var caption := ""
@export var color := Color("#ebebeb")

@export_group("Story")
@export_file("*.dialogue") var conversation_file
@export var conversation_sect: String

@export_group("Procedural Generation")
@export var spawn_cost:int   # in [0..100] for normal cases

# core combat attributes
@export_group("Combat")
@export var health := 50
@onready var health_full = health  # health can only go above this level in exceptional cases
@export var strength := 50
@export var agility := 50
@export var intelligence := 50
@export var perception := 50
@export var healing_prob := 0.05  # %chance to heal at any given turn
@export var resistance: Consts.DamageFamily = Consts.DamageFamily.NONE  # at most one!

@export var faction := Factions.NONE

# bestiary entry
@export_group("Bestiary")
@export_file("*.png", "*.jpg", "*.jpeg") var bestiary_img
@export_multiline var description

var state = States.IDLE

# Turn logic: when possible, use `state`, await on `turn_done()` and ttl/decay rather than
# relying on specific turn number values.
var current_turn: int
var conditions_turn: int
var acted_turn: int

var nb_active_anims := 0
var dest  # keep track of where we are going while animations are running 

func _get_configuration_warnings():
	var warnings = []
	if name != "Hero" and find_children("", "Strategy").is_empty():
		update_configuration_warnings()
		warnings.append("Actor's can't act without a strategy.")
	return warnings

func _ready():
	$Label.text = char
	$Label.add_theme_color_override("font_color", color)

func _to_string():
	var parent = get_parent()
	if parent:
		parent = parent.name
	var coord_str = RevBoard.coord_str(get_cell_coord())
	return "<Actor %s on %s at %s>" % [name, parent, coord_str]

func ddump():
	print(self)
	print("  health: %s/%s" % [health, health_full])
	print("  core stats: %s" % get_base_stats())
	print("  modifiers:  %s" % get_modifiers())

func is_idle() -> bool:
	return state == States.IDLE

func is_acting() -> bool:
	return state == States.ACTING

func is_listening() -> bool:
	return state == States.LISTENING
	
func stop_listening():
	assert(is_listening())
	state = States.IDLE

func act():
	## Do the action for this turn (might include passing).
	## The actor over loads this method to select the action based on player input.
	state = States.ACTING
	var strat = get_strategy()
	if not strat:
		finalize_turn()
		return
	var action = strat.act()
	if action != null:
		action.connect("finished", finalize_turn, CONNECT_ONE_SHOT)
	else:
		finalize_turn()
	return action

func get_caption():
	if caption:
		return caption
	else:
		return name

func get_modifiers():
	## return a dict of all the modifiers from items and conditions combined together
	return Utils.get_node_modifiers(self)

func get_stat(stat_name, challenge=null):
	## Return the effective stat with all the active modifiers included
	assert(stat_name in Consts.CORE_STATS, "%s is not a core stat" % stat_name)
	var mods = get_modifiers()
	return get(stat_name) + mods.get(stat_name, 0) + mods.get(challenge, 0)

func get_base_stats():
	## Return a dictionnary of the core stats without any modifiers applied
	var stats = {}
	for name in Consts.CORE_STATS:
		stats[name] = get(name)
	return stats

func stat_roll(stat_name, challenge=null):
	## Return a random number in [0..1] weighted by the given stat. 
	## The distribution is uniform.
	## 0 is terrible, 1 is glorious
	var stat = get_stat(stat_name, challenge)
	# 1% better stat than MU gives 1% higher return on average 
	return (1 + (stat - MU) / 100.0) * randf()

func stat_trial(difficulty, stat_name, challenge=null):
	## Return true if a random stat_roll is >= than difficulty
	## Typical difficulties should be from 0 (trivial) to 100 (extremely hard), 
	## but the scale is unbounded.
	var stat = get_stat(stat_name, challenge)
	return difficulty >= randfn(stat, SIGMA)

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

func start_turn(current_turn_:int):
	## Mark the start a new game turn, but we do not play until act() is called.
	current_turn = current_turn_

func finalize_turn():
	state = States.IDLE
	acted_turn = current_turn
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

func place(board_coord, immediate:=false):
	## Place the actor at the specific coordinate without animations.
	## No tests are done to see if board_coord is a suitable location.
	## immediate: don't wait for the Actor to finish their turn, some interference 
	##   with animations is possible.
	var old_coord = get_cell_coord()
	if not immediate:
		if state == States.ACTING:
			await self.turn_done
		if is_animating():
			await anims_done
	reset_dest()
	position = RevBoard.board_to_canvas(board_coord)
	emit_signal("moved", old_coord, board_coord)
	
func move_by(cell_vect: Vector2i):
	## Move by the specified number of tiles from the current position. 
	## The move is animated, return the animation.
	var new_pos = RevBoard.canvas_to_board(position) + cell_vect
	return move_to(new_pos)
	
func move_to(board_coord):
	## Move to the specified board coordinate in number of tiles from the 
	## origin. 
	## The move is animated, return the animation.
	var old_coord = get_cell_coord()
	var anim := create_anim()
	var cpos = RevBoard.board_to_canvas(board_coord)
	anim.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	anim.tween_property(self, "position", cpos, .3)
	dest = board_coord
	anim.finished.connect(reset_dest, CONNECT_ONE_SHOT)
	# TODO: it might be better to emit at the end of the animation
	emit_signal("moved", old_coord, board_coord)
	return anim

func travel_to(there):
	## Start the multi-turn journey that takes us to `there`, 
	##   return `false` if the journey is not possible.
	## Depending on where we are in the turn logic, the caller might need to call `stop_listening()` 
	## for the travelling strategy to kick in, otherwise, it will only be active on the next turn.
	var path = get_board().path(get_cell_coord(), there)
	if path == null or path.size() == 0:
		return false
	else:
		assert(false, "broken for now, circular imports???")
#		var strat = Traveling.new(there, path, self, 0.9)
#		add_child(strat)
		return true

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
	print("hit %s for %s dmg" % [foe, damage])
	play_sound("HitSound", weapon)
	
	foe.update_health(-damage)
	foe.emit_signal("was_attacked", self)
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
	assert(false, "Could not play any sound for %s!" % node_name)

func _anim_health_change(label_, number, direction:Vector2):
	var label = label_.duplicate()
	add_child(label)
	label.text = "%d" % number
	label.visible = true
	var anim := create_anim()
	anim.finished.connect(label.queue_free, CONNECT_ONE_SHOT)
	var offset = Vector2(RevBoard.TILE_SIZE, RevBoard.TILE_SIZE) * direction
	anim.tween_property(label, "position", label.position+offset, .5)
	var anim2 := create_anim()
	anim2.pause()
	# start the fadeout about half way through
	anim2.tween_property(label, "modulate", Color(0, 0, 0, 0), .25)
	var timer := get_tree().create_timer(.25)
	timer.timeout.connect(anim2.play)
	return anim

func update_health(hp_delta: int):
	## Update our health and animate the event.
	## Return the animation.
	if hp_delta == 0:
		return  # don't animate 0 deltas
	
	health += hp_delta
	emit_signal("health_changed", health)
		
	var anim = null
	if hp_delta < 0:
		anim = _anim_health_change($DamageLabel, -hp_delta, Vector2(.25, -.5))
	else:
		anim = _anim_health_change($HealingLabel, hp_delta, Vector2(.25, .5))
		
	if health <= 0:
		play_sound("DeathSound")
		emit_signal("died")
		# we do not need create_anim() since sub-tweens have the same signal as the root tween
		var anim3 = anim.parallel()  
		anim3.tween_property($Label, "modulate", Color(.8, 0, 0, .7), .1)
		anim3.tween_property($Label, "modulate", Color(0, 0, 0, 0), .4)
		anim3.finished.connect(self.queue_free, CONNECT_ONE_SHOT)
	return anim

func _learn_attack(attacker):
	## Remember who just hit us.
	$Mem.learn("was_attacked", current_turn, Memory.Importance.NOTABLE, {"attacker": attacker})

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

func get_conversation():
	## Return a {res:..., sect:...} dict or null if the actor has nothing to say
	## Actors with eloborate conversation logic should overload this method without 
	##   even calling the parent implementation.
	if conversation_file == null or len(conversation_file) == 0:
		return null
	var res = load(conversation_file)
	var sect = null
	if conversation_sect:
		sect = conversation_sect
	elif res.get_titles():
		sect = res.get_titles()[-1]
	return {"res": res, "sect": sect}

func get_conditions():
	var conds = []
	for node in get_children():
		if node is Effect.Condition:
			conds.append(node)
	return conds

func get_weapons():
	## Return all the active weapons for the current turn.
	## All active weapons are eligible for a strike during the turn.
	## Ex: a fast feline would return a bite and two claw weapons.
	return find_children("", "Weapon")

func get_items():
	var items = []
	for node in get_children():
		if node is Item:
			items.append(node)
	return items

func get_evasion(weapon):
	## Return the evasion stat against a particular weapon. 
	return get_stat("agility")
	
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
	if stat_trial(foe.get_evasion(weapon), "agility"):
		# Miss!
		return anim_miss(foe, weapon)

	# TODO: agility should influence the chance of a critical hit	
	var roll = randfn(MU, SIGMA)
	if roll > MU + 2*SIGMA:
		crit = true

	# damage roll		
	# TODO: use intelligence for spells
	var damage = stat_roll("strength") * weapon.damage
	if crit:
		damage *= CRITICAL_MULT
	damage = foe.normalize_damage(weapon, damage)
	weapon.apply_all_effects(foe)
	return anim_hit(foe, weapon, damage)

func normalize_damage(weapon, damage):
	## Return the number of hit points after applying resistances and minimums with `self` as 
	## the receiver of `damage`.
	# TODO: should probably replace all calls with normalize_health_delta()
	damage *= get_resist_mult(weapon)
	return max(1, round(damage))

func normalize_health_delta(vector, h_delta):
	## a more generic version of `normalize_damage()` that works for healing and non-weapons.
	assert(h_delta != 0, "delta must be strictly positive (healing) or strictly negative (damage)")
	h_delta = h_delta * get_resist_mult(vector) as int
	
	# check for overhealing
	if not vector.magical and health + h_delta > health_full:
		return health_full - health
	
	if h_delta > 0:
		return max(1, h_delta)
	else:
		return min(-1, h_delta)

func activate_conditions():
	## give all conditions and innate body repair a chance to heal us or make us suffer
	assert(health_full != null)
	if health < health_full and Rand.rstest(healing_prob):
		regen()
	for cond in get_conditions():
		if is_alive():  # there is a chance that we won't make it through all the conditions
			cond.erupt()
	conditions_turn = current_turn

func regen(delta:=1):
	## Regain some health from natural healing
	## Do nothing if health is already full
	assert(delta>=0, "this is for healing, use something else for damage")
	if health + delta > health_full:
		delta = health_full - health
	if delta:
		add_message("%s healed a little" % get_caption())
		update_health(delta)

func drop_item(item):
	assert(item.get_parent() == self, "must possess an item before dropping it")
	var board = get_board()
	var builder = BoardBuilder.new(board)
	builder.place(item, false, get_cell_coord(), false)
	
func pick_item(item):
	# TODO: dist() == 1 would also work nicely
	var item_coord = item.get_cell_coord()
	assert(item_coord == get_cell_coord(), "can only pick items that are under us")
	item.visible = false
	item.reparent(self)
	emit_signal("picked_item", item_coord)

func consume_item(item: Item):
	## activate the item and remove is from inventory
	assert(item.consumable)
	item.activate_on_actor(self)
	# the item will free itself, but we have to remove it from inventory to prevent 
	# reuse before the free happens
	if item.get_parent():
		item.get_parent().remove_child(item)
		$/root.add_child(item)
	add_message("%s used a %s" % [get_caption(), item.get_short_desc()])
	
func add_message(message):
	## Try to add a message to the message window. 
	## The visibility of the message depends on us being visible to the Hero 
	var board = get_board()
	if board != null:
		board.add_message(self, message)
		
