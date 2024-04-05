# Copyright © 2023-2024 Yannick Gingras <ygingras@ygingras.net> and contributors

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

# heavily inspired by dialogue_manager/example_balloon/example_balloon.gd

## A rudimentatry speech bubble
class_name DialoguePane extends Control

signal closed(acted:bool)
signal new_sentiment(faction_a, faction_b, value:int)
signal quest_activated()

var dia_res: DialogueResource
var temp_game_states := []
var speaker = null
var speaker_name: String:
	get:
		return speaker.caption

var dialogue_line: DialogueLine:
	get:
		return dialogue_line
	set(next_dialogue_line):
		if not next_dialogue_line:
			close()
			return
		
		# Remove any previous responses
		for node in %ResponsesBox.get_children():
			node.hide()
			node.queue_free()
		
		dialogue_line = next_dialogue_line
		%SpeakerLabel.text = dialogue_line.character
		%DialogueLabel.dialogue_line = dialogue_line

		# Show response options
		if len(dialogue_line.responses):
			for i in len(dialogue_line.responses):
				var response = dialogue_line.responses[i]
				# Duplicate the template so we can grab the fonts, sizing, etc
				var item = %ResponseTemplate.duplicate()
				var action = _on_response_gui_input.bind(i)
				item.gui_input.connect(action)
				if not response.is_allowed:
					item.modulate.a = 0.7
				item.text = response.text
				%ResponsesBox.add_child(item)
			%DialogueLabel.finished_typing.connect(_show_options, CONNECT_ONE_SHOT)
		
		if not dialogue_line.text.is_empty():
			%DialogueLabel.type_out()
			await %DialogueLabel.finished_typing

func _ready():
	# make sure we have space to fit most convos without meeting a scroll bar
	var line_height = %ResponseTemplate.get_line_height()
	var nb_resp = %SpeechBackgroud.size.y / line_height
	if nb_resp < 10:
		# this is actually smaller than 10 since margins and other controls 
		# are also taking space
		%SpeechBackgroud.custom_minimum_size.y = 10 * line_height

func _unhandled_key_input(event):
	# TODO: handle ui_accept key as well
	if visible and event.is_action_pressed("ui_cancel"):
		# TODO: advance if typing, close otherwise
		accept_event()
		if %DialogueLabel.is_typing:
			finish_typing()
		else:
			close()

func _unhandled_input(event):
	if visible and event is InputEventKey:
		# Consume all keyboard input while the balloon is visible
		accept_event()
	
func start(dia_res_: DialogueResource, title: String, speaker_=null, extra_game_states: Array = []):
	## Start a dialogue sequence
	temp_game_states = extra_game_states + [self]
	dia_res = dia_res_
	speaker = speaker_
	# TODO: blank out everything before showing
	self.dialogue_line = await dia_res.get_next_dialogue_line(title, temp_game_states)
	show()

func close():
	hide()
	# talking to someone always counts as a turn action, event if you exit the conversation early.
	emit_signal("closed", true)  

func advance():
	## Finish typing or go to the next message.
	if %DialogueLabel.is_typing:
		finish_typing()
	elif not has_options():
		next(dialogue_line.next_id)

func next(next_id: String):
	## Go to the next message, or close the pane if we are done.
	self.dialogue_line = await dia_res.get_next_dialogue_line(next_id, temp_game_states)

func _on_response_gui_input(event, option_idx):
	if Utils.event_is_tap_or_left(event) and event.pressed:
		next(dialogue_line.responses[option_idx].next_id)

func _on_background_gui_input(event):
	# Consume all input while the balloon is visible
	if visible:
		accept_event()
		if Utils.event_is_tap_or_left(event) and not event.pressed:
			# We do our processing on release to fully consume both the tap 
			# and the release.
			advance()

func finish_typing():
	%DialogueLabel.skip_typing()
	%DialogueLabel.emit_signal("finished_typing")
	
func has_options():
	return len(dialogue_line.responses) != 0

func _show_options():
	for child in %ResponsesBox.get_children():
		child.show()

### dialogue action functions ###
# We invoke the following with `do funct()` instructions in the dialogue text.

func checkpoint(title):
	## Remember a dialogue checkpoint and start there next time we talk to the current speaker
	assert(title in dia_res.get_titles())
	if speaker:
		speaker.conversation_sect = title

func event_happened(event) -> bool:
	## Return whether something has already happend from the point of view of the hero.
	var hero = Tender.hero
	return hero.mem.recall(event, hero.current_turn) != null

func speaker_learns(event_name, importance:=Memory.Importance.NOTABLE, by_hero=true):
	var data = null
	## Add a fact to the speaker's memory
	if by_hero:
		data = {"by":Tender.hero.actor_id}
	speaker.mem.learn(event_name, speaker.current_turn, importance, data)

func speaker_feels_insulted(by_hero=true):
	speaker_learns("was_insulted", Memory.Importance.NOTABLE, by_hero)
	var offender = null
	if by_hero:
		offender = Tender.hero
	speaker.was_offended.emit(offender)
	
func speaker_forgives():
	speaker.forgive(Tender.hero)
	Tender.hero.forgive(speaker)

func speaker_recalls(event_name) -> bool:
	return speaker.mem.recall(event_name, speaker.current_turn) != null

func speaker_recalls_nb(event_name) -> int:
	assert(false, "broken, always returns 0 when used in the dialogue")
	return speaker.mem.recall_nb(event_name, speaker.current_turn)

func speaker_has_gifts(extra_tags:=[]) -> bool:
	if speaker == null:
		return false
	var include_tags = ["gift"] + extra_tags
	return len(speaker.get_items(include_tags)) > 0

func speaker_give_item(extra_tags=null):
	## Pass an item from the speaker to the hero
	## extra_tags: if supplied, the given item must have all those tags
	var tags = ["gift"]
	if extra_tags:
		tags += extra_tags
	var items = speaker.get_items(tags, [], false)
	var item = Rand.choice(items)
	speaker.give_item(item, Tender.hero)

func speaker_give_items(extra_tags=null):
	## Pass all gifts from the speaker to the hero
	## extra_tags: if supplied, the given item must have all those tags
	var tags = ["gift"]
	if extra_tags:
		tags += extra_tags
	var items = speaker.get_items(tags, [], false)
	for item in items:
		speaker.give_item(item, Tender.hero)

func hero_has_item(include_tags=null, exclude_tags=null) -> bool:
	return not Tender.hero.get_items(include_tags, exclude_tags).is_empty()

func hero_give_item(include_tags=null, exclude_tags=null):
	## pass an item from the hero to the speaker
	var items = Tender.hero.get_items(include_tags, exclude_tags, false)
	var item = Rand.choice(items)
	Tender.hero.give_item(item, speaker)

func hero_give_items(include_tags=null, exclude_tags=null):
	## pass items from the hero to the speaker
	var items = Tender.hero.get_items(include_tags, exclude_tags, false)
	for item in items:
		Tender.hero.give_item(item, speaker)

func hero_learns(event_name, importance:=Memory.Importance.NOTABLE, by_speaker=true):
	var data = null
	## Add a fact to the hero's memory
	if by_speaker:
		data = {"by":speaker.actor_id}
	Tender.hero.mem.learn(event_name, speaker.current_turn, importance, data)

func hero_recalls(event_name) -> bool:
	return Tender.hero.mem.recall(event_name, Tender.hero.current_turn) != null

func hero_recalls_nb(event_name) -> int:
	assert(false, "broken, always returns 0 when used in the dialogue")
	return Tender.hero.mem.recall_nb(event_name, Tender.hero.current_turn)

func hero_is_foe(actor_tags=[]):
	## Return if someone considers the hero a foe.
	## The actor of reference is found with `actor_tags` or if `speaker` if no tags are provided
	## If more than one actor matches all tags, return `true` as long as at least
	## one considers the hero a foe.
	if actor_tags.is_empty():
		return speaker.is_foe(Tender.hero)
	else:
		var board = speaker.get_board()
		for actor in board.get_actors():
			if Utils.has_tags(actor, actor_tags):
				if actor.is_foe(Tender.hero):
					return true
		return false

func show_message(message):
	Tender.hero.add_message(message)

func set_global_sentiment(value:int):
	## Change the sentiment between the speaker's faction and the hero's faction.
	Tender.sentiments.set_sentiment(speaker.faction, Tender.hero.faction, value)

func activate_quest():
	## Mark the current quest as active, this will update the quest log
	Tender.quest.is_active = true
	quest_activated.emit()
	
