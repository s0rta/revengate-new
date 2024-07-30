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

class_name MessagesPane extends Control

const DECAY_SECS := 5.0
const FADEOUT_SECS := 1.0
const MAX_MESSAGES = 10

## message tag to theme types in "src/ui/theme.tres"
const MSG_STYLES = {"msg:combat": "MsgCombat", 
					"msg:healing": "MsgHealing",
					"msg:regen": "MsgHealing",
					"msg:vibe": "MsgVibe", 
					"msg:story": "MsgVibe", 
					"msg:inventory": "MsgInventory",
					"msg:magic": "MsgMagic", 
					"msg:alt": "MsgAlt"}

func _ready():
	%MessageTemplate.hide()

func _remove_dups(text) -> int:
	## Hide previous messages that are similar to 'text', return how many were hidden
	var nb_dups := 0
	for label in %MessagesBox.find_children("", "Label", false, false):
		if label.visible and label.text.begins_with(text):
			var inc = 1
			# TODO: we recover the previous multiplier from a suffix of the previous 
			#    string, but this is brittle. Storing the multiplier as a node property 
			#    would be more robust.
			if len(label.text) - len(text) >= 2:
				var tail = label.text.substr(len(text))
				if tail.begins_with(" x"):
					inc = tail.substr(2).to_int()
			nb_dups += inc
			label.hide()
	return nb_dups


func add_message(text, level:Consts.MessageLevels, tags:=[]):
	_trim_old_messages()
	var label = %MessageTemplate.duplicate()
	if level >= Consts.MessageLevels.WARNING:
		label.modulate = Color.RED
	else:
		for tag in tags:
			if MSG_STYLES.has(tag):
				label.theme_type_variation = MSG_STYLES[tag]
				break  # only the first tag style is applied
	var nb_dups = _remove_dups(text)
	if nb_dups:
		label.text = "%s x%d" % [text, nb_dups + 1]
	else:
		label.text = text
	%MessagesBox.add_child(label)
	label.show()
	%Panel.show()
	var timer = get_tree().create_timer(DECAY_SECS)
	await timer.timeout
	_fadeout_node(label)

func _fadeout_node(node):
	if node.visible:
		var tree = get_tree()
		var anim = tree.create_tween()
		anim.tween_property(node, "modulate:a", 0.0, FADEOUT_SECS)
		await anim.finished
		node.hide()
	node.queue_free()
	
	# hide the panel when all the messages have decayed
	var has_visible = false
	for label in %MessagesBox.find_children("", "Label", false, false):	
		if label.visible:
			has_visible = true
			break
	if not has_visible:
		%Panel.hide()

func _trim_old_messages():
	var labels = %MessagesBox.get_children()
	if len(labels) > MAX_MESSAGES:
		for i in (len(labels) - MAX_MESSAGES):
			labels[1+i].hide()
