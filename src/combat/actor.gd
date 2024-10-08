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

@tool
@icon("res://assets/dcss/cyclops_new.png")
class_name Actor extends Area2D

# the internal state changed
signal state_changed(new_state)
# the actor won't play again until the turn counter is incremented
signal turn_done
# the actor is done moving, but it could move again during the current turn
signal anims_done
# tried to hit `foe` but missed
signal missed(foe)
# successfully hit `victim` for `damage` hit points
signal hit(victim, damage)
# the actor was the victim of an attack
signal was_attacked(attacker)
# the actor was the victim of an offense
signal was_offended(offender)
# health changed, either got better or worst
signal health_changed(new_health)
# mana changed, either up or down
signal mana_changed(new_mana)
# learned or forgot a spell
signal spells_changed
# the actor met their ultimate demise
signal died(old_coord, tags)
# the actor moved to a new location on the current board
signal moved(from, to)
# the actor picked an item that used to be at `old_coord`
signal picked_item(old_coord)
# the actor removed an item from their inventory and left it at `coord`
signal dropped_item(coord)
# the actor's active weapon(s) changed
signal changed_weapons()
# the actor stopped automating their actions with a(some) strategy(ies),
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

# weapons start sucking if you throw them too far
const TOO_FAR_MOD = 0.5

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
@export var spawn_cost:float  ## in [0..100] for normal cases
@export_range(0.0,1.0) var spawn_prob := 1.0  ## probability that this gets added to a deck on a per board basis
@export var spawn_rect:Rect2i  ## A sub-section of the board to spawn in

# core combat attributes
@export_group("Combat")
@export var health := 50
# health can only go above this level in exceptional cases, -1 to auto-set to `health`
@export var health_full := -1
@export_range(0.0, 1.0) var healing_prob := 0.05  # %chance to heal at any given turn
@export var strength := 50
@export var agility := 50
@export var intelligence := 50
@export var perception := 50
@export var mana := 0
@export var mana_full := -1
@export var mana_burn_rate := 100
@export_range(0.0, 1.0) var mana_recovery_prob := 0.1
@export var resistance: Consts.DamageFamily = Consts.DamageFamily.NONE  # at most one!
@export var tags:Array[String]

@export var faction := Consts.Factions.NONE

# bestiary entry
@export_group("Bestiary")
@export_file("*.png", "*.jpg", "*.jpeg") var bestiary_img
@export_multiline var description := ""

# Those are not meant to be customized in the editor, but they exported anyway to
# make the object save better
@export_group("Internals")
# Turn logic: when possible, use `state`, await on `turn_done()` and ttl/decay rather than
# relying on specific turn numbers.
@export var current_turn: int
@export var conditions_turn: int
@export var acted_turn: int

# keep track of where we are going while animations are running
@export var dest:Vector2i = Consts.COORD_INVALID

@export var mem: Memory
@export var actor_id := 0

var state = States.IDLE:
	set(new_state):
		state = new_state
		emit_signal("state_changed", new_state)

var has_acted: bool  # reset at the start of every turn
var _anims := []  # all turn-blocking anims
var shrouded := false
var _shroud_anim = null
var _mods_cache = null


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
	var parent = get_parent()
	assert(parent != $/root,
			"Don't run Actor as its own scene, try it in a simulator or in the game instead.")

	if mem == null and not Engine.is_editor_hint() and parent is RevBoard:
		mem = Memory.new()
	elif not parent is RevBoard:
		mem = null
	if not was_attacked.is_connected(_learn_attack):
		was_attacked.connect(_learn_attack)
	picked_item.connect(_clear_mods_cache)

func _to_string():
	var parent = get_parent()
	if parent:
		if parent is RevBoard:
			var coord_str = RevBoard.coord_str(get_cell_coord())
			return "<Actor %s(%s) on %s at %s>" % [name, char, parent.name, coord_str]
		else:
			return "<Actor %s(%s) on %s>" % [name, char, parent.name]
	else:
		return "<Actor %s(%s)>" % [name, char]

func ddump():
	print(self)
	print("  health: %s/%s" % [health, health_full])
	print("  core stats: %s" % get_base_stats())
	print("  modifiers:  %s" % get_modifiers())
	print("  skills:  %s" % get_skills())
	print("  conditions: %s" % [get_conditions()])
	print("  is_unexposed(): %s" % is_unexposed())
	print("  should shroud: %s" % should_shroud())
	if Tender.hero != null:
		if Tender.hero.perceives(self):
			print("  perceived by Hero")
		if perceives(Tender.hero):
			print("  perceives Hero")
	mem.ddump_summary(current_turn, "  ")

func ddump_pos():
	print("Officially at %s" % RevBoard.coord_str(get_cell_coord()))
	if dest and dest != Consts.COORD_INVALID:
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
	## Stop waiting for player input without signaling.
	## To make the TurnQueue move passed this actor, cancel_action() is probably
	## what you are looking for.
	assert(is_listening())
	state = States.IDLE

func cancel_action():
	## Stop doing whatever we are doing and mark us as having played this turn.
	# As long as `has_acted` has been properly set by any action code invoked since the
	# beginning of the turn, we don't have any cleanup to do besides ending our turn.
	finalize_turn()

func act() -> void:
	## Do the action for this turn (might include passing).
	## `acted_turn` will be set to the current turn if the action costed the turn (most actions do).
	## The Hero overloads this method to select the action based on player input.
	has_acted = false
	state = States.ACTING
	_mods_cache = null
	refresh_strategies()
	var strat = get_strategy()
	if strat:
		has_acted = await strat.act()
	finalize_turn()
	return

func spawn():
	## Mark sub-nodes to make then properly save and restore.
	## This should be called exactly once after a newly created actor has been added to a board.
	mem = Memory.new()
	if health_full <= 0:
		health_full = health
	if mana_full <= 0:
		mana_full = mana
	if not actor_id:
		actor_id = ResourceUID.create_id()
	for item in get_items([], [], false):
		var copy = item.duplicate()
		copy.owner = null
		add_child(copy)
		item.reparent($"/root")
		item.queue_free()

func restore():
	## Filter sub-node and keep only the ones that should be restored.
	## This should be called exactly once per actor after a reloaded game has
	## been added to the scene tree.
	for item in get_items([], [], false):
		if item.owner == self:
			item.reparent($"/root")
			item.queue_free()
		else:
			item.show()

func get_caption():
	if caption:
		return caption
	else:
		return name

func get_short_desc():
	return "(%s) %s" % [char, get_caption()]

func _clear_mods_cache(_arg=null):
	_mods_cache = null

func get_modifiers():
	## return a dict of all the modifiers from items and conditions combined together
	var no_skill = Consts.SkillLevel.NEOPHYTE
	var knows_how_to_use = func (node):
		var skill_name = node.get("skill")
		if skill_name:
			return get_skill(skill_name) != Consts.SkillLevel.NEOPHYTE
		else:
			return true
	return Utils.get_node_modifiers(self, knows_how_to_use)

func get_skills():
	## Return a {skill_name->level} mapping
	return Utils.get_node_skills(self)

func get_skill(skill_name) -> Consts.SkillLevel:
	## Return the level of a skill.
	## Unknown skills return Consts.SkillLevel.NEOPHYTE
	return get_skills().get(skill_name, Consts.SkillLevel.NEOPHYTE)

func set_skill(skill_name, level):
	var skill_node = null
	var nodes = find_children("", "SkillLevels", false, false)
	nodes = nodes.filter(func (node): return node.owner != self)  # built-in nodes do not save updates
	if nodes.is_empty():
		skill_node = SkillLevels.new()
		add_child(skill_node)
	else:
		skill_node = nodes[0]
	skill_node.set(skill_name, level)

func get_stat(stat_name, challenge=null):
	## Return the effective stat with all the active modifiers and skills included
	assert(stat_name in Consts.CORE_STATS, "%s is not a core stat" % stat_name)

	# are we trained to perform that specific challenge?
	var skill_mod = 0
	if challenge in Consts.SKILLS:
		var level = get_skills().get(challenge, Consts.SkillLevel.NEOPHYTE)
		skill_mod = CombatUtils.skill_modifier(level)

	if _mods_cache == null:
		_mods_cache = get_modifiers()
	var eff_stat = get(stat_name) + _mods_cache.get(stat_name, 0)
	var challenge_mod = _mods_cache.get(challenge, 0)
	return eff_stat + challenge_mod + skill_mod

func get_base_stats():
	## Return a dictionnary of the core stats without any modifiers applied
	var stats = {}
	for name in Consts.CORE_STATS:
		stats[name] = get(name)
	return stats

func mana_cost(base_cost):
	## Return the mana cost for the actor after taking into account all its modifiers
	return max(1, base_cost * get_stat("mana_burn_rate") / 100)

func has_mana(base_cost):
	## Return whether the actor has enough mana to perform a spell of a
	## given `base_cost` (the cost before taking into account modifiers).
	return mana >= mana_cost(base_cost)

func use_mana(base_cost):
	## Decrease mana. The effective number of mana points will differ from `base_cost` if the
	## actor has modifiers.
	## Return how many mana points were used.
	var cost = mana_cost(base_cost)
	mana -= cost
	mana_changed.emit(mana)
	return cost

func add_spell(spell:Spell):
	if spell.get_parent():
		spell.reparent(self)
	else:
		add_child(spell)
	spells_changed.emit()

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

func get_board() -> RevBoard:
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
	if $DeathSound and $DeathSound.playing:
		await $DeathSound.finished
	queue_free()

func start_turn(new_turn:int):
	## Mark the start a new game turn, but we do not play until act() is called.
	# If we have been out of play for a turn or more (ex.: on an innactive board), we push the
	# expiration of our sub-components and trigger conditions for once for each missed turn.
	# This might hurt!

	# activate_conditions() adequately verifies if we have we died along the way...
	var multi_step_nodes = []
	for node in get_children():
		if node.get("start_turn"):
			node.start_turn(new_turn)
		elif node.get("start_new_turn"):
			multi_step_nodes.append(node)

	# Process one conditions event per turn, skip everything if we've already seen new_turn,
	# which might happen if the TurnQueue has been paused and restarted in the middle of a turn.
	for i in new_turn - current_turn:
		activate_conditions()
		for node in multi_step_nodes:
			node.start_new_turn()
	current_turn = new_turn
	_mods_cache = null

func finalize_turn(acted=null):
	## Cleanup internal state, pass the control back to the TurnQueue.
	## `acted`: if provided, overrides `has_acted` to decide if our actions costed a turn.
	state = States.IDLE
	if acted != false and (acted or has_acted):
		acted_turn = current_turn
	turn_done.emit()

func reset_dest(former_dest=null):
	if former_dest == null or dest == former_dest:
		dest = Consts.COORD_INVALID

func get_cell_coord() -> Vector2i:
	## Return the board position occupied by the actor.
	## If the actor is currently moving, return where it's expected to be at the
	## end of the turn.
	if dest != Consts.COORD_INVALID:
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

func move_by(cell_vect: Vector2i) -> void:
	## Move by the specified number of tiles from the current position.
	## The move is animated.
	var new_pos = RevBoard.canvas_to_board(position) + cell_vect
	move_to(new_pos)

func move_to(board_coord) -> void:
	## Move to the specified board coordinate in number of tiles from the
	## origin.
	## The move is animated.
	# only animating if the player would see it
	if is_unexposed() and get_board().is_cell_unexposed(board_coord):
		place(board_coord, true)
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

func move_toward_actor(actor) -> bool:
	## Try to take one step toward `actor`, return true if it worked.
	var here = get_cell_coord()
	var there = actor.get_cell_coord()
	assert(here != there, "Can't go towards %s, already there!" % [actor])
	var path = get_board().path(here, there, false)
	if path != null and len(path) >= 2:
		move_to(path[1])
		return true
	else:
		return false

func travel_to(there, index=null):
	## Start the multi-turn journey that takes us to `there`,
	##   return `false` if the journey is not possible.
	## Depending on where we are in the turn logic, the caller might need to call `stop_listening()`
	## for the travelling strategy to kick in, otherwise, it will only be active on the next turn.
	var path = get_board().path_perceived(get_cell_coord(), there, self, true, -1, index)
	if path == null or path.size() == 0:
		return false
	else:
		var strat = Traveling.new(there, path, self, 0.9)
		add_child(strat)
		return true

func add_strategy(strat:Strategy):
	if strat.me != self:
		strat.me = self
	add_child(strat)

func refresh_strategies():
	## Ask strategie to update their awareness of the world.
	for strat in find_children("", "Strategy", false, false):
		strat.refresh(current_turn)

func cancel_strategies():
	## Force the expiration of all strategies that can be expired.
	var has_cancelled = false
	for strat in find_children("", "Strategy", false, false):
		if strat.cancellable:
			strat.cancel()
			has_cancelled = true
	if has_cancelled:
		emit_signal("strategy_expired")

func get_strategy():
	## Return the best strategy for this turn or `null` if no strategy is currently valid.
	var pri_desc = func(a, b):
		return a.priority >= b.priority
	var strats = find_children("", "Strategy", false, false)
	strats.sort_custom(pri_desc)
	for strat in strats:
		if strat.is_valid():
			return strat
	return null

func has_strategy(cancellable=false):
	## Return `true` if the actor has any valid strategy.
	## cancellable: the strategies must also be cancellable.
	for strat in find_children("", "Strategy", false, false):
		if strat.is_valid():
			if cancellable:
				return strat.cancellable
			else:
				return true
	return false

func _get_lunge_anim_cpos(where):
	## Return the canvas coord where an attack animation should reach before starting the
	## retreat animation.
	## `where`: an actor, possibly a foe, or a coord
	# going roughtly half a cell towards foe, no matter how far foe is
	var here = get_cell_coord()
	where = CombatUtils.as_coord(where)
	var attack_vec = Vector2(where - here)
	attack_vec = attack_vec.normalized()
	var anim_vec = 0.45 * attack_vec
	return position + anim_vec * RevBoard.TILE_SIZE

func _anim_lunge(where):
	## Return the animation of lunging forward towards `where` then retreaing.
	## `where`: a coord or an actor
	var anim_dest = _get_lunge_anim_cpos(where)
	var old_cpos = position
	var anim := create_anim()
	anim.set_trans(anim.TRANS_SINE)
	anim.tween_property(self, "position", anim_dest, .15)
	anim.tween_property(self, "position", old_cpos, .2)
	return anim

func anim_miss(foe, weapon):
	## Animate a missed strike towards `foe`
	play_sound("MissSound", weapon)
	_anim_lunge(foe)

func anim_hit(foe, weapon, damage):
	## Animate a success strike on `foe`
	play_sound("HitSound", weapon)
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
	label.add_to_group("no-save", true)
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

func get_health_ratio() -> float:
	## Return a number in 0..inf (typically in 0..1) reprensenting our current
	## fraction of health_full.
	return 1.0 * health / health_full

func update_health(hp_delta: int):
	## Update our health and animate the event.
	if hp_delta == 0:
		return  # don't animate 0 deltas

	health += hp_delta
	health_changed.emit(health)

	if not is_unexposed():
		# animate visible health changes
		if hp_delta < 0:
			_anim_health_change($DamageLabel, -hp_delta, Vector2(.25, -.5))
		else:
			_anim_health_change($HealingLabel, hp_delta, Vector2(.25, .5))

	if health <= 0:
		die()

func update_mana(mana_delta: int):
	## Update our mana.
	if mana_delta == 0:
		return  # nothing to do

	mana += mana_delta
	mana_changed.emit(mana)

func die():
	## Animate our ultimate demise, drop our inventory, then remove ourself from this cruel world.
	if not is_hero():
		# any death is attributed to the Hero
		CombatUtils.add_kill(caption)
	emit_signal("died", get_cell_coord(), tags)
	for item in get_items(null, null, false):
		drop_item(item)

	if is_unexposed():
		_dissipate()
	else:
		play_sound("DeathSound")
		var anim = create_anim()
		anim.tween_property($Label, "modulate", Color(.8, 0, 0, .7), .3)
		anim.tween_property($Label, "modulate", Color(0, 0, 0, 0), .7)
		anim.finished.connect(self._dissipate, CONNECT_ONE_SHOT)

func _learn_attack(attacker):
	## Remember who just hit us.
	mem.learn("was_attacked", current_turn, Memory.Importance.NOTABLE,
			{"by": attacker.actor_id})

func is_alive():
	return health > 0

func is_dead():
	return not is_alive()

func is_expired():
	return is_dead()

func is_unexposed(index=null):
	## Return if this actor is where the hero shouldn't be aware of them

	# not inside a valid game
	if Tender.hero == null:
		return true

	# on a board other than the active one
	var parent = get_parent()
	if parent == null or not parent is RevBoard or not parent.is_active():
		return true

	# out of sight
	if Tender.hero and not Tender.hero.perceives(self, index):
		return true

	return false

func recalls_offense(other=null):
	## Return whether we recall ever being offended
	## `other`: if provided, only offences by this actor are considered
	var pred = null
	if other != null:
		pred = func (fact): return fact.by == other.actor_id
	return mem.recall_any(Consts.OFFENSIVE_EVENTS, current_turn, pred) != null

func forgive(other: Actor):
	## Forget any past offences by `other`
	mem.forget_all(Consts.OFFENSIVE_EVENTS, func (fact): return fact.by == other.actor_id)

func is_friend(other: Actor):
	## Return whether `self` has positive sentiment towards `other`
	if not Tender.sentiments:
		return false
	return Tender.sentiments.is_friend(self, other) and not recalls_offense(other)

func is_foe(other: Actor):
	## Return whether `self` has negative sentiment towards `other`
	if Tender.sentiments:
		return Tender.sentiments.is_foe(self, other) or recalls_offense(other)
	else:
		return false

func is_neutral(other: Actor):
	## Return whether `self` has neutral sentiment towards `other`
	if Tender.sentiments:
		return Tender.sentiments.is_neutral(self, other) and not recalls_offense(other)
	else:
		return true

func get_perception_ranges():
	## Return a Dictionary with details of various perception ranges
	var percep = get_stat("perception")
	var min = 1
	return {"sight": max(min, MAX_SIGHT_DIST / 100.0 * percep),
			"aware": max(min, MAX_AWARENESS_DIST / 100.0 * percep),
			"feel": min}

func perceives(thing, index=null):
	## Return whether we can perceive `thing`
	if thing == null:
		return false  # something that used to exist but died or got consumed
	var ranges = get_perception_ranges()
	var board = get_board()
	var here = get_cell_coord()
	var there = CombatUtils.as_coord(thing)
	if thing is Actor and thing == self:
		return true
	elif not (thing is Vector2i) and board != thing.get_board():
		return false

	var dist = Geom.euclid_dist(here, there)
	if dist > ranges.sight:
		return false
	elif dist <= ranges.feel:
		return true
	elif dist <= ranges.aware:
		# no sight needed if you are close enough to smell/hear/feel them
		if board.path_potential(here, there, ranges.aware):
			return true
	# In sight-only range: perceived when there is a clear line of sight
	if index == null:
		return board.line_of_sight(here, there) != null
	else:
		return index.has_los(here, there)

func perceives_free(coord:Vector2i, index:RevBoard.BoardIndex):
	## Return whether we think that `coord` is walkable and unoccupied.
	var board = index.board
	if not board.is_walkable(coord):
		return false
	var actor = index.actor_at(coord)
	if actor != null and perceives(coord, index):
		return false
	return true

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

func get_vibe_cards():
	## Return the vibe cards that this monster can add to the procgen deck.
	## Cards will be considered, but there is no guaranty that any will be drawn.
	return find_children("", "Vibe", false, false)

func get_conditions():
	var conds = []
	for node in get_children():
		if node is Condition:
			conds.append(node)
	return conds

func get_max_weapon_range():
	var str = get_stat("strength")
	var max_range = 0

	for weapon in get_weapons():
		var weapon_range = get_eff_weapon_range(weapon)
		if (weapon is Weapon or weapon is InnateWeapon) and weapon_range > max_range:
			max_range = weapon_range
	return max_range

func get_max_action_range(other:Actor):
	## Return how close you have to be to perform any action with `other`
	var weapon_range = get_max_weapon_range()
	if other.get_conversation():
		return max(Consts.CONVO_RANGE, weapon_range)
	else:
		return weapon_range

func get_throw_range():
	# linearly adjusted range based on your strength
	var str = get_stat("strength")
	return int(0.06 * str)

func get_eff_weapon_range(weapon):
	# linearly adjusted range based on your strength (str=50 -> weapon.range)
	var str = get_stat("strength")
	return max(1, int(weapon.range * 2.0 * str / 100.0))

func get_weapons():
	## Return all the active weapons for the current turn.
	## All active weapons are eligible for a strike during the turn.
	## Ex.: a fast feline would return a bite and two claw weapons.
	## Actors are only using their innate weapons when they do not have item weapons equipped.
	var has_equipped_weapon = false
	for node in get_children():
		if node is Weapon and node.is_equipped:
			has_equipped_weapon = true
			break

	var all_weapons = []
	for node in get_children():
		if not has_equipped_weapon and node is InnateWeapon:
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

func get_items(include_tags=null, exclude_tags=null, grouped=true):
	## Return an array of the items in our inventory.
	## include_tags: if provided, only items that have all those tags are returned.
	## exclude_tags: if provided, only items that have none of those tags are returned.
	## grouped: similar items are returned as one ItemGrouping
	var loose_items = []
	for node in get_children():
		if node is Item:
			if include_tags != null and not Utils.has_tags(node, include_tags):
				continue
			if exclude_tags != null and Utils.has_any_tags(node, exclude_tags):
				continue
			loose_items.append(node)

	if not grouped:
		return loose_items

	var items = []
	var groupings = []
	var was_grouped = false
	for item in loose_items:
		if "groupable" in item.tags:
			was_grouped = false
			for group in groupings:
				if item.is_groupable_with(group.top()):
					group.add(item)
					was_grouped = true
					break
			if not was_grouped:
				var grouping = ItemGrouping.new()
				grouping.add(item)
				groupings.append(grouping)
				items.append(groupings[-1])
		else:
			items.append(item)

	return items

func get_compatible_item(ref_item:Item):
	## Return an arbitrary item that can be groupped with `ref_item` (same inventory slot).
	## Return `null` if `ref_item` is the only one of its kind in the actor's inventory.
	var items = get_items(ref_item.tags, null, false)
	for item in items:
		if item != ref_item and ref_item.is_groupable_with(item):
			return item
	return null

func get_compatible_items(ref_item:Item):
	## Return an Array of items that can be groupped with `ref_item` (same inventory slot).
	## The array can be empty.
	var items = get_items(ref_item.tags, null, false)
	var compats = []
	for item in items:
		if item != ref_item and ref_item.is_groupable_with(item):
			compats.append(item)
	return compats

func get_spells(include_tags=null, exclude_tags=null):
	## Return an array of known spells.
	## include_tags: if provided, only spells that have all those tags are returned.
	## exclude_tags: if provided, only spells that have none of those tags are returned.
	var spells = []
	for node in get_children():
		if node is Spell:
			if include_tags != null and not Utils.has_tags(node, include_tags):
				continue
			if exclude_tags != null and Utils.has_any_tags(node, exclude_tags):
				continue
			spells.append(node)
	return spells

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

func attack(foe) -> bool:
	## A full multi-strike attack on foe.
	## Return whether at least one strike has landed as a hit.
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

func strike(foe:Actor, weapon, throw=null):
	## Strike foe with weapon. The strike could result in a miss.
	## The result is immediately visible in the world.
	## `throw`: whether the weapon will leave our hand; auto-detect if null
	# combats works with two random rolls: to-hit then damage.
	mem.learn("attacked", current_turn, Memory.Importance.TRIVIAL,
			{"foe": foe.actor_id})
	foe.was_offended.emit(self)

	var with_anims = not is_unexposed()
	var crit = false
	var here := get_cell_coord()
	var foe_coord := foe.get_cell_coord()
	# to-hit
	# pre-compute the to-hit bonnus from features
	var hit_mod = _get_feature_modifier(foe, weapon, TO_HIT_FEATURE_MODS)

	var attack_dist = Geom.cheby_dist(here, foe_coord)
	if throw == null:
		throw = Utils.has_tags(weapon, ["throwable"]) and attack_dist > 1
	if throw:
		# re-equip from the same stack when tossing things
		if weapon.is_equipped:
			var next_weapon = get_compatible_item(weapon)
			reequip_weapon_from_group(next_weapon, weapon)
		drop_item(weapon, foe_coord, false)

	if stat_trial(foe.get_evasion(weapon), "agility", weapon.skill, hit_mod):
		# Miss!
		foe.mem.learn("was_targeted",
						current_turn,
						Memory.Importance.TRIVIAL,
						{"by": actor_id})
		if with_anims:
			anim_miss(foe, weapon)
		missed.emit(foe)
		return false

	# TODO: agility should influence the chance of a critical hit
	var roll = randfn(MU, SIGMA)
	if roll > MU + 2*SIGMA:
		crit = true

	# damage roll
	# TODO: use intelligence for spells
	var dmg_mod = _get_feature_modifier(foe, weapon, DAMAGE_FEATURE_MODS)
	var range_mod = 1.0
	if throw and get_eff_weapon_range(weapon) < attack_dist:
		range_mod = TOO_FAR_MOD
	var damage = stat_roll("strength") * (weapon.damage + dmg_mod) * range_mod
	if crit:
		damage *= CRITICAL_MULT
	damage = foe.normalize_damage(weapon, damage)
	foe.update_health(-damage)
	if weapon.get("has_effect"):
		CombatUtils.apply_all_effects(weapon, foe)
	emit_signal("hit", foe, damage)
	add_message("%s hit %s for %d dmg" % [get_short_desc(), foe.get_short_desc(), damage],
				Consts.MessageLevels.INFO,
				["msg:combat"])
	foe.was_attacked.emit(self)
	if with_anims and not foe.is_unexposed():
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
	if not Utils.has_tags(vector, ["magical"]) and health + h_delta > health_full:
		return health_full - health

	if h_delta > 0:
		return max(1, h_delta)
	else:
		return min(-1, h_delta)

func activate_conditions():
	## give all conditions and innate body repair a chance to heal us or make us suffer
	assert(health_full != null)
	if health < health_full and Rand.rstest(get_stat("healing_prob")):
		regen()
	if mana < mana_full and Rand.rstest(get_stat("mana_recovery_prob")):
		refocus()
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
	if delta > 0:
		add_message("%s healed a little" % get_caption(),
					Consts.MessageLevels.INFO,
					["msg:regen", "msg:healing"])
		update_health(delta)

func refocus(delta:=1):
	## Regain some mana from natural recovery
	## Do nothing if mana is already full
	assert(delta>=0, "this is for mana recovery, use something else for magic usage")
	if mana + delta > mana_full:
		delta = mana_full - mana
	if delta > 0:
		add_message("%s seems more focused" % get_caption(),
					Consts.MessageLevels.INFO,
					["msg:regen", "msg:magic"])
		update_mana(delta)

func equip_item(item, exclusive=true):
	## Equip the item (typically a weapon).
	## If `exclusive`, all other items are deequipped first
	if item is Node:
		assert(item.get_parent() == self, "Must own an item before it can be equipped.")
	if exclusive:
		for other in get_items(null, null, false):
			if other.get("is_equipped") != null:
				other.is_equipped = false
	item.is_equipped = true
	_mods_cache = null
	emit_signal("changed_weapons")

func drop_item(item, coord=null, anim_toss=true):
	assert(item.get_parent() == self, "must possess an item before dropping it")
	if item.get("is_equipped"):
		item.is_equipped = false
		emit_signal("changed_weapons")
	var board = get_board()
	var builder = BoardBuilder.new(board)
	if coord == null:
		coord = get_cell_coord()
	elif anim_toss:
		_anim_lunge(coord)
	coord = builder.place(item, false, coord, false)
	_mods_cache = null
	dropped_item.emit(coord)

func reequip_weapon_from_group(grouping, prev_weapon=null):
	if grouping == null or grouping is ItemGrouping and grouping.is_empty():
		if prev_weapon != null:
			add_message("You ran out of %s" % prev_weapon.get_short_desc(),
						Consts.MessageLevels.INFO,
						["msg:inventory"])
		else:
			add_message("You ran out of your previous weapons",
						Consts.MessageLevels.INFO,
						["msg:inventory"])
	else:
		equip_item(grouping)

func give_item(item, actor=null):
	## Give `item` to `actor`
	## If actor is not provided, the item is simply destroyed.
	assert(item.get_parent() == self, "must possess an item before giving it away")
	var new_parent = actor
	if not new_parent:
		new_parent = $root
	item.reparent(new_parent)
	item.remove_tag("gift")  # NPCs keep track of giftable inventory with the "gift" tag
	if actor:
		add_message("%s gave a %s to %s" % [self.get_caption(), item.get_short_desc(), actor.get_caption()],
					Consts.MessageLevels.INFO,
					["msg:inventory"])
	else:
		add_message("%s gave a %s" % [self.get_caption(), item.get_short_desc()],
					Consts.MessageLevels.INFO,
					["msg:inventory"])
		item.queue_free()

func pick_item(item):
	# TODO: dist() == 1 would also work nicely
	var item_coord = item.get_cell_coord()
	assert(item_coord == get_cell_coord(), "can only pick items that are under us")

	item.shroud(false)
	item.reset_display()
	if item.get("is_equipped") != null:
		item.is_equipped = false
	item.reparent(self)
	picked_item.emit(item_coord)
	add_message("%s added to %s's inventory" % [item.get_short_desc(), caption],
				Consts.MessageLevels.INFO,
				["msg:inventory"])

func consume_item(item: Item):
	## activate the item and remove is from inventory
	assert(item.consumable)
	item.activate_on_actor(self)
	item.hide()
	# the item will free itself, but we have to remove it from inventory to prevent
	# reuse before the free happens
	if item.get_parent():
		item.reparent($/root)
	add_message("%s used a %s" % [get_caption(), item.get_short_desc()],
				Consts.MessageLevels.INFO,
				["msg:inventory"])

func add_message(text:String,
				level:Consts.MessageLevels=Consts.MessageLevels.INFO,
				tags:=[]):
	## Try to add a message to the message window.
	## The visibility of the message depends on us being visible to the Hero
	## Any direct child of the actor can block a message by implementing filter_message() and
	## returning false for the same args as add_message()
	if level == null:
		level = Consts.MessageLevels.INFO
	for node in get_children():
		var filter = node.get("filter_message")
		if filter != null and not filter.call(text, level, tags):
			return
	var board = get_board()
	if board != null:
		board.add_message(self, text, level, tags)
