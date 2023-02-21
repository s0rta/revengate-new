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

# heavily inspired by dialogue_manager/example_balloon/example_balloon.gd

## A rudimentatry speech bubble
class_name DialoguePane extends Control

signal something_happened(msg)

var dia_res: DialogueResource
var temp_game_states := []
var is_waiting_for_input := false
var seen_michel := false

var dialogue_line: DialogueLine:
	get:
		return dialogue_line
	set(next_dialogue_line):
		is_waiting_for_input = false
		if not next_dialogue_line:
			hide()
			return
		
		# Remove any previous responses
		for node in %ResponsesBox.get_children():
			node.queue_free()
		
		dialogue_line = next_dialogue_line
		
		%SpeakerLabel.visible = not dialogue_line.character.is_empty()
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
				item.show()
				%ResponsesBox.add_child(item)
		
		if not dialogue_line.text.is_empty():
			%DialogueLabel.type_out()
			await %DialogueLabel.finished_typing
		
		# Wait for input
		is_waiting_for_input = true

func _gui_input(event):
	Utils.ddump_event(event, self, "_gui_input")

func _unhandled_input(event):
	Utils.ddump_event(event, self, "_unhandled_input")
	# Consume all keyboard input while the balloon is visible
	# TODO: handle ui_cancel and ui_accept keys
	if visible and event is InputEventKey:
		accept_event()

func _is_left_released(event):
	if event is InputEventMouseButton and not event.is_pressed():
		if event.button_index == MOUSE_BUTTON_LEFT:
			return true
	return false
	
func start(dia_res_: DialogueResource, title: String, extra_game_states: Array = []):
	## Start a dialogue sequence
	temp_game_states = extra_game_states + [self]
	is_waiting_for_input = false
	dia_res = dia_res_
	# TODO: blank out everything before showing
	show()
	self.dialogue_line = await dia_res.get_next_dialogue_line(title, temp_game_states)

func advance():
	if %DialogueLabel.is_typing:
		finish_typing()
	elif not has_options():
		next(dialogue_line.next_id)
	else:
		print("Not advancing: waiting for player selection...")

func next(next_id: String):
	self.dialogue_line = await dia_res.get_next_dialogue_line(next_id, temp_game_states)

func do_a_dance(text):
	print("Dance to the tune of: %s" % text)

func _on_response_gui_input(event, option_idx):
	Utils.ddump_event(event, self, "_on_response_gui_input")
	if _is_left_released(event):
		next(dialogue_line.responses[option_idx].next_id)

func _on_background_gui_input(event):
	Utils.ddump_event(event, self, "_on_background_gui_input")
	# Consume all input while the balloon is visible
	if visible:
		accept_event()
		if _is_left_released(event):
			advance()

func finish_typing():
	# TODO: also call the remaining in-line mutations.
	%DialogueLabel.visible_ratio = 1.0
	%DialogueLabel.has_finished = true
	%DialogueLabel.is_typing = false
	%DialogueLabel.emit_signal("finished_typing")
	
func has_options():
	return len(dialogue_line.responses) != 0
