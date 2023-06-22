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
@icon("res://assets/dcss/cyclops_new.png")
class_name Actor extends Area2D

# the internal state changed
signal state_changed(new_state)
# the actor won't play again until the turn counter is incremented
signal turn_done  
# the actor is done moving, but it could move again during the current turn
signal anims_done  
# the actor was the victim of an attack
signal was_attacked(attacker)
# health changed, either got better or worst
signal health_changed(new_health)
# the actor met their ultimate demise
signal died(old_coord)
# the actor moved to a new location on the current board
signal moved(from, to)
# the actor picked an item that used to be at `old_coord`
signal picked_item(old_coord)
# the actor removed an item from their inventory and left it at `coord`
signal dropped_item(coord)
# the actor stopped automating its actions with a(some) strategy(ies),
# might fire more than once per strategy
signal strategy_expired

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
# victim-tag -> weapon-tag -> to-hit modifier
const TO_HIT_FEATURE_MODS = {"ethereal": {"silver": 30}}
# victim-tag -> weapon-tag -> damage modifier
const DAMAGE_FEATURE_MODS = {"undead": {"silver": 3}}

# 35% more damage on a critical hit
const CRITICAL_MULT := 0.35

# Perception
const MAX_SIGHT_DIST = 30  # perfect sight
const MAX_AWARENESS_DIST = 8  # perfect out-of-sight sensing

# main visuals
@export_group("Visuals")
@export var char := "x"
@export var caption := ""
@export var color := Color("#ebebeb")

@export_group("Story")
@export_file("*.dialogue") var conversation_file
@export var conversation_sect: String

@export_group("Procedural Generation")
@export var spawn_cost:float   # in [0..100] for normal cases

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
@export var tags:Array[String]

@export var faction := Consts.Factions.NONE


# bestiary entry
@export_group("Bestiary")
@export_file("*.png", "*.jpg", "*.jpeg") var bestiary_img
@export_multiline var description

@onready var mem = $Mem
var state = States.IDLE:
	set(new_state):
		state = new_state
		emit_signal("state_changed", new_state)

# Turn logic: when possible, use `state`, await on `turn_done()` and ttl/decay rather than
# relying on specific turn number values.
var current_turn: int
var conditions_turn: int
var acted_turn: int

var _anims := []  # all turn-blocking anims
var shrouded := false
var _shroud_anim = null
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
	Utils.assert_all_tags(tags)
	Utils.hide_unplaced(self)

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
	print("  skills:  %s" % get_skills())
	if Tender.hero.perceives(self):
		print("  perceived by Hero")
	if perceives(Tender.hero):
		print("  perceives Hero")

func ddump_pos():
	print("Officially at %s" % RevBoard.coord_str(get_cell_coord()))
	if dest:
		print("  going to %s" % RevBoard.coord_str(dest))
	print("  is_animating: %s nb_anims:%d" % [is_animating(), len(_anims)])
	var fcoord = Vector2(1.0 * position.x / RevBoard.TILE_SIZE, 
						1.0 * position.y / RevBoard.TILE_SIZE)
	print("  pos: %s fractional cell: [%s:%s]" % [position, fcoord.x, fcoord.y])

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
	## Return if an action happened. This does not influence turn logic, but it migh
	##   influence visuals.
	## The Hero overloads this method to select the action based on player input.
	state = States.ACTING
	refresh_strategies()
	var strat = get_strategy()
	if not strat:
		finalize_turn()
		return false
	var acted = await strat.act()
	finalize_turn()
	return acted

func get_caption():
	if caption:
		return caption
	else:
		return name

func get_modifiers():
	## return a dict of all the modifiers from items and conditions combined together
	return Utils.get_node_modifiers(self)

func get_skills():
	return Utils.get_node_skills(self)

func get_stat(stat_name, challenge=null):
	## Return the effective stat with all the active modifiers and skills included
	assert(stat_name in Consts.CORE_STATS, "%s is not a core stat" % stat_name)
	
	# are we trained to perform that specific challenge?
	var skill_mod = 0
	if challenge in Consts.SKILLS:
		var level = get_skills().get(challenge, Consts.SkillLevel.NEOPHYTE)
		skill_mod = CombatUtils.skill_modifier(level)

	var mods = get_modifiers()
	var eff_stat = get(stat_name) + mods.get(stat_name, 0)
	var challenge_mod = mods.get(challenge, 0)
	#print("get_stat(%s, %s): %s, %s, %s" % [stat_name, challenge, eff_stat, 
	#										challenge_mod, skill_mod])
	return eff_stat + challenge_mod + skill_mod

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

func stat_trial(difficulty, stat_name, challenge=null, modifier:=0):
	## Return true if a random stat_roll is >= than difficulty
	## Typical difficulties should be from 0 (trivial) to 100 (extremely hard), 
	## but the scale is unbounded.
	## Modifier: added to the hero stat
	var stat = get_stat(stat_name, challenge) + modifier
	return difficulty >= randfn(stat, SIGMA)

func is_hero():
	return Tender.hero != null and Tender.hero == self

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

func _dec_active_anims(old_anim:Tween):
	var old_size = len(_anims)
	_anims.erase(old_anim)
	
	# TODO: This _usually_ makes the anim.finished signal propagate to all it's 
	#   handlers, but not all the time. We need something more reliable.
	old_anim.kill()
	
	if _anims.is_empty():
		emit_signal("anims_done")

func create_anim() -> Tween:
	## Return a Tween animation for this actor, register the anim as active.
	var anim = create_tween()
	_anims.append(anim)
	var cleanup_func = _dec_active_anims.bind(anim)
	anim.finished.connect(cleanup_func, CONNECT_ONE_SHOT)
	return anim

func is_animating():
	## Return whether the actor is currently performing an animation.
	return not _anims.is_empty()

func _dissipate():
	## Do some cleanup, then vanish forever
	queue_redraw()
	queue_free()

func start_turn(new_turn:int):
	## Mark the start a new game turn, but we do not play until act() is called.
	# If we have been out of play for a turn or more (ex.: on an innactive board), we push the 
	# expiration of our sub-components and trigger conditions for once for each missed turn. 
	# This might hurt!
	
	# FIXME: see if we have we died along the way?
	var multi_step_nodes = []
	for node in get_children():
		if node.get("start_turn"):
			node.start_turn(new_turn)
		elif node.get("start_new_turn"):
			multi_step_nodes.append(node)
	for i in new_turn - current_turn:
		activate_conditions()
		for node in multi_step_nodes:
			if node.is_expired():
				break
			node.start_new_turn()
	current_turn = new_turn

func finalize_turn():
	state = States.IDLE
	acted_turn = current_turn
	emit_signal("turn_done")

func reset_dest(inval_dest=null):
	if dest and dest == inval_dest:
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

func should_hide(_index=null):
	return not get_parent() is RevBoard

func should_shroud(index=null):
	return is_unexposed(index)

func shroud(animate=true):
	Utils.shroud_node(self, animate)
		
func unshroud(animate=true):
	Utils.unshroud_node(self, animate)

func move_by(cell_vect: Vector2i):
	## Move by the specified number of tiles from the current position. 
	## The move is animated, return the animation.
	var new_pos = RevBoard.canvas_to_board(position) + cell_vect
	return move_to(new_pos)
	
func move_to(board_coord):
	## Move to the specified board coordinate in number of tiles from the 
	## origin. 
	## The move is animated.
	# only animating if the player would see it
	if is_unexposed() and get_board().is_cell_unexposed(board_coord):
		place(board_coord)
	else:
		# FIXME: kill() the previous anim if it's not done
		assert(not is_animating(), "reset_dest won't work if we start moving before the previous move is over")
		
		var old_coord = get_cell_coord()
		var anim := create_anim()
		var cpos = RevBoard.board_to_canvas(board_coord)
		anim.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		anim.tween_property(self, "position", cpos, .2)
		dest = board_coord
		
		var inval_func = reset_dest.bind(board_coord)
		anim.finished.connect(inval_func, CONNECT_ONE_SHOT)
		
		# We emit before the end of the animation, which allows for more
		# overlap between our active turn and other visual changes.
		emit_signal("moved", old_coord, board_coord)
	return true

func move_toward_actor(actor):
	## Try to take one step toward `actor`, return true if it worked.
	var here = get_cell_coord()
	var there = actor.get_cell_coord()
	var path = get_board().path(here, there, false)
	if path != null and len(path) >= 2:
		return move_to(path[1])
	else:
		return false

func travel_to(there, index=null):
	## Start the multi-turn journey that takes us to `there`, 
	##   return `false` if the journey is not possible.
	## Depending on where we are in the turn logic, the caller might need to call `stop_listening()` 
	## for the travelling strategy to kick in, otherwise, it will only be active on the next turn.
	var path = get_board().path_perceived(get_cell_coord(), there, self, null, index)
	if path == null or path.size() == 0:
		return false
	else:
		var strat = Traveling.new(there, path, self, 0.9)
		add_child(strat)
		return true

func refresh_strategies():
	## Ask strategie to update their awareness of the world.
	for node in get_children():
		if node is Strategy:
			node.refresh(current_turn)

func cancel_strategies():
	## Force the expiration of all strategies that can be expired.
	var has_cancelled = false
	for node in get_children():
		if node is Strategy and node.cancellable:
			node.cancel()
			has_cancelled = true
	if has_cancelled:
		emit_signal("strategy_expired")

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

func has_strategy(cancellable=false):
	## Return `true` if the actor has any valid strategy.
	## cancellable: the strategies must also be cancellable.
	for node in get_children():
		if node is Strategy and node.is_valid():
			if cancellable:
				return node.cancellable
			else:
				return true
	return false

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
	play_sound("MissSound", weapon)

	var anim = _anim_lunge(foe)
	return anim

func anim_hit(foe, weapon, damage):
	## Animate a success strike on `foe`, return the animation object.
	print("hit %s for %s dmg" % [foe, damage])
	play_sound("HitSound", weapon)
	
	foe.update_health(-damage)
	foe.emit_signal("was_attacked", self)
	if not (is_unexposed() and foe.is_unexposed()):
		_anim_lunge(foe)

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
	if is_unexposed():
		return
	var label = label_.duplicate()
	add_child(label)
	label.text = "%d" % number
	label.visible = true
	var tree = get_tree()
	var anim := tree.create_tween()
	anim.finished.connect(label.queue_free, CONNECT_ONE_SHOT)
	var offset = Vector2(RevBoard.TILE_SIZE, RevBoard.TILE_SIZE) * direction
	anim.tween_property(label, "position", label.position+offset, .5)
	var anim2 := tree.create_tween()
	anim2.pause()
	# start the fadeout about half way through
	anim2.tween_property(label, "modulate", Color(0, 0, 0, 0), .25)
	var timer := get_tree().create_timer(.25)
	timer.timeout.connect(anim2.play)

func update_health(hp_delta: int):
	## Update our health and animate the event.
	## Return the animation.
	if hp_delta == 0:
		return  # don't animate 0 deltas
	
	health += hp_delta
	emit_signal("health_changed", health)
	
	if is_unexposed():
		return  # don't animate off-board health changes
		
	var anim = null
	if hp_delta < 0:
		_anim_health_change($DamageLabel, -hp_delta, Vector2(.25, -.5))
	else:
		_anim_health_change($HealingLabel, hp_delta, Vector2(.25, .5))
		
	if health <= 0:
		die()

func die():
	## Animate our ultimate demise, drop our inventory, then remove ourself from this cruel world.
	emit_signal("died", get_cell_coord())
	if not is_hero():
		CombatUtils.add_kill(caption)
	for item in get_items():
		drop_item(item)

	if is_unexposed():
		_dissipate()
	else:
		play_sound("DeathSound")
		var anim = create_anim()
		anim.tween_property($Label, "modulate", Color(.8, 0, 0, .7), .1)
		anim.tween_property($Label, "modulate", Color(0, 0, 0, 0), .4)
		anim.finished.connect(self._dissipate, CONNECT_ONE_SHOT)

func _learn_attack(attacker):
	## Remember who just hit us.
	$Mem.learn("was_attacked", current_turn, Memory.Importance.NOTABLE, {"attacker": attacker})

func is_alive():
	return health > 0
	
func is_dead():
	return not is_alive()

func is_expired():
	return is_dead()

func is_unexposed(index=null):
	## Return if this actor is where the hero should could be aware of them
	
	# on a board other than the active one
	var parent = get_parent()
	if parent == null or not parent.visible:
		return true

	# out of sight
	if Tender.hero and not Tender.hero.perceives(self, index):
		return true

	return false

func is_friend(other: Actor):
	## Return whether `self` has positive sentiment towards `other`
	return faction != Consts.Factions.NONE and faction == other.faction
	
func is_foe(other: Actor):
	## Return whether `self` has negative sentiment towards `other`
	return faction != Consts.Factions.LUX_CO and other.faction == Consts.Factions.LUX_CO
	
func is_impartial(other: Actor):
	## Return whether `self` has neutral sentiment towards `other`
	return !is_friend(other) and !is_foe(other)

func perceives(thing, index=null):
	## Return whether we can perceive `thing`
	var percep = get_stat("perception")
	var min = 1
	var sight_dist = min + MAX_SIGHT_DIST / 100.0 * percep
	var aware_dist = min + MAX_AWARENESS_DIST / 100.0 * percep
	var board = get_board()
	var here = get_cell_coord()
	var there = CombatUtils.as_coord(thing)
	if thing is Actor and thing == self:
		return true
	elif percep <= 0:
		return false
	elif not (thing is Vector2i) and board != thing.get_board():
		return false

	var dist = board.dist(self, there)
	if dist > sight_dist:
		return false
	elif dist <= min:
		return true
	elif dist <= aware_dist:
		# no sight needed if you are close enough to smell/hear/feel them
		if board.path_potential(here, there, aware_dist):
			return true
	# In sight-only range: perceived when there is a clear line of sight
	if index == null:
		return board.line_of_sight(self, thing) != null
	else:
		return index.has_los(self, thing)

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
	## Ex.: a fast feline would return a bite and two claw weapons.
	var all_weapons = []
	for node in get_children():
		if node is InnateWeapon:
			all_weapons.append(node)
		elif node is Weapon and node.is_equipped:
			all_weapons.append(node)

	# filter out innacives based on probability
	var active_weapons = []
	for weapon in all_weapons:
		var prob = weapon.get("probability")
		if prob == null or Rand.rstest(prob):
			active_weapons.append(weapon)

	# Pick a fallback weapon when all probabilistic selections failed
	if active_weapons.is_empty() and not all_weapons.is_empty():
		var weights = []
		for weapon in all_weapons:
			var prob = weapon.get("probability")
			weights.append(prob if prob!= null else 1.0)
		return [Rand.weighted_choice(all_weapons, weights)]
	return active_weapons

func get_items(tag=null):
	## Return an array of the items in our inventory.
	## tag: if null, all the items are returned, 
	##   otherwise, only the items with this tag are returned.
	var items = []
	for node in get_children():
		if node is Item and (tag == null or tag in node.tags):
			items.append(node)
	return items

func get_evasion(_weapon):
	## Return the evasion stat against a particular weapon. 
	return get_stat("agility", "evasion")
	
func get_resist_mult(weapon):
	## Return a multiplier to attenuate `weapon`'s damage based on our resistances.
	## The multiplier is in [0..1], with 1 being full damage
	if !resistance:
		return 1.0
	elif weapon.damage_family == resistance:
		return RESIST_MULT
	else:
		return 1.0
	
func _get_feature_modifier(foe, weapon, feature_table):
	## Return the feature-specific modifier(s) when attacking `foe` with `weapon`. 
	## Return 0 if the weapon has no feature that apply to this attack.
	## feature_table: TO_HIT_FEATURE_MODS, DAMAGE_FEATURE_MODS, or a similar table
	var mod = 0
	for victim_tag in foe.tags:
		var feature_mods = feature_table.get(victim_tag, {})
		for weapon_tag in weapon.tags:
			mod += feature_mods.get(weapon_tag, 0)
	return mod
	
func attack(foe):
	## A full multi-strike attack on foe.
	## Sentiment and range are not checked, the caller is responsible for 
	## performing those tests.
	var has_hit = false
	var weapons = get_weapons()
	
	for weapon in weapons:
		var wait_time = 0
		if foe.is_alive():
			if is_animating():
				wait_time = await anims_done
			has_hit = strike(foe, weapon) or has_hit
	return has_hit

func strike(foe:Actor, weapon):
	## Strike foe with weapon. The strike could result in a miss. 
	## The result is immediately visible in the world.
	# combats works with two random rolls: to-hit then damage.
	
	var crit = false
	# to-hit
	# pre-compute the to-hit bonnus from features
	var hit_mod = _get_feature_modifier(foe, weapon, TO_HIT_FEATURE_MODS)
	if stat_trial(foe.get_evasion(weapon), "agility", weapon.skill, hit_mod):
		# Miss!
		anim_miss(foe, weapon)
		return false

	# TODO: agility should influence the chance of a critical hit	
	var roll = randfn(MU, SIGMA)
	if roll > MU + 2*SIGMA:
		crit = true

	# damage roll
	# TODO: use intelligence for spells
	var dmg_mod = _get_feature_modifier(foe, weapon, DAMAGE_FEATURE_MODS)
	var damage = stat_roll("strength") * (weapon.damage + dmg_mod)
	if crit:
		damage *= CRITICAL_MULT
	damage = foe.normalize_damage(weapon, damage)
	CombatUtils.apply_all_effects(weapon, foe)
	anim_hit(foe, weapon, damage)
	return true

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
	if item.get("is_equipped") != null:
		item.is_equipped = false
	var board = get_board()
	var builder = BoardBuilder.new(board)
	var coord = builder.place(item, false, get_cell_coord(), false)
	emit_signal("dropped_item", coord)

func give_item(item, actor:Actor):
	## Give `item` to `actor`
	assert(item.get_parent() == self, "must possess an item before giving it away")
	item.reparent(actor)
	item.tags.erase("gift")  # NPCs keep track of giftable inventory with the "gift" tag
	add_message("%s gave a %s to %s" % [self.get_caption(), item.get_short_desc(), actor.get_caption()])

func pick_item(item):
	# TODO: dist() == 1 would also work nicely
	var item_coord = item.get_cell_coord()
	assert(item_coord == get_cell_coord(), "can only pick items that are under us")
	item.visible = false
	if item.get("is_equipped") != null:
		item.is_equipped = false
	item.reparent(self)
	emit_signal("picked_item", item_coord)

func consume_item(item: Item):
	## activate the item and remove is from inventory
	assert(item.consumable)
	item.activate_on_actor(self)
	item.hide()
	# the item will free itself, but we have to remove it from inventory to prevent 
	# reuse before the free happens
	if item.get_parent():
		item.reparent($/root)
	add_message("%s used a %s" % [get_caption(), item.get_short_desc()])
	
func add_message(message):
	## Try to add a message to the message window. 
	## The visibility of the message depends on us being visible to the Hero 
	var board = get_board()
	if board != null:
		board.add_message(self, message)
		
