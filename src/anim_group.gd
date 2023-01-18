# Copyright © 2022–2023 Yannick Gingras <ygingras@ygingras.net> and contributors

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

## A group of tween animations.
## This class privides aggregate synchronisation primitives for all the animations in the group.
class_name AnimGroup extends Node

signal finished

var parent: Node
var anims := []
var _finished_count = 0

static func dump_anim(anim:Tween):
	var details = {"is_running": anim.is_running(),
					"is_valid": anim.is_valid(), 
					"elapsed_time": anim.get_total_elapsed_time()}
	print("Details for anim %s: %s" % [anim, details])

func _init(parent_:Node, anims_:Array=[]):
	parent = parent_
	parent.add_child(self)
	for anim in anims_:
		add(anim)

func add(anim:Tween):
	assert(anim not in anims, "AnimGroup members must be unique.")
	anims.append(anim)
	anim.finished.connect(_inc_finished, CONNECT_ONE_SHOT)
	
func create_anim() -> Tween:
	## Return a newly created that is part of this group
	var anim = parent.create_tween()
	add(anim)
	return anim
	
func is_running() -> bool:
	for anim in anims:
		if anim.is_running():
			return true
	return false

func _inc_finished():
	_finished_count += 1
	_check_finished()
	
func _check_finished():
	if not is_running() and _finished_count >= anims.size():
		emit_signal("finished")
		queue_free()
