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

var dia_res: DialogueResource
var temp_game_states := []
var is_waiting_for_input := false

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

		# Show any responses we have
		if len(dialogue_line.responses):
			for response in dialogue_line.responses:
				# Duplicate the template so we can grab the fonts, sizing, etc
				var item: RichTextLabel = %ResponseTemplate.duplicate(0)
				if not response.is_allowed:
					item.modulate.a = 0.7
				print("adding response option: %s" % response.text)
				item.text = response.text
				item.show()
				%ResponsesBox.add_child(item)
		
		if not dialogue_line.text.is_empty():
			%DialogueLabel.type_out()
			await %DialogueLabel.finished_typing
		
		# Wait for input
		is_waiting_for_input = true

func _input(event):
#	Utils.ddump_event(event, self, "_input")
	if visible:
		if is_waiting_for_input:
			accept_event()
		if _is_left_released(event):
			advance()

#func _gui_input(event):
#	Utils.ddump_event(event, self, "_gui_input")

func _unhandled_input(event):
#	Utils.ddump_event(event, self, "_unhandled_input")
	# Consume all input while the balloon is visible
	if is_waiting_for_input and visible:
		accept_event()
		if _is_left_released(event):
			advance()

func _is_left_released(event):
	if event is InputEventMouseButton and not event.is_pressed():
		if event.button_index == MOUSE_BUTTON_LEFT:
			return true
	return false
	
func start(dia_res_: DialogueResource, title: String, extra_game_states: Array = []):
	## Start a dialogue sequence
	temp_game_states = extra_game_states
	is_waiting_for_input = false
	dia_res = dia_res_
	# TODO: blank out everything before showing
	show()
	self.dialogue_line = await dia_res.get_next_dialogue_line(title, temp_game_states)

func advance():
	if %DialogueLabel.is_typing:
		%DialogueLabel.visible_ratio = 1
	else:
		next(dialogue_line.next_id)

func next(next_id: String):
	self.dialogue_line = await dia_res.get_next_dialogue_line(next_id, temp_game_states)

func _on_responses_gui_input(event: InputEvent, item: Control) -> void:
	# FIXME: this must be connected
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		next(dialogue_line.responses[item.get_index()].next_id)

func _on_dialogue_label_spoke(letter, letter_index, speed):
	print("speaking: %s" % [[letter, %DialogueLabel.visible_characters, %DialogueLabel.visible_ratio]])
