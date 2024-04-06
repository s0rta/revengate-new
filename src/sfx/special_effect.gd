# Copyright © 2023–2024 Yannick Gingras <ygingras@ygingras.net> and contributors

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

## A special effect with both audio and visual components
class_name SpecialEffect extends Node2D

## should the VFX remove itself from the scene tree after flashing
@export var auto_free := true

@export_range(0.0, 10.0) var max_screen_time := 5.0

@export_group("Debug")
@export var skip_particles := false
@export var skip_sound := false
@export var skip_shader := false

# only set on linear effects like the electric arc
var start_coord:Vector2i
var end_coord:Vector2i

# not using TIME in the shader(s) because we want to be able to set the effect start time 
# from GDScript
var time: float

func _ready():
	time = 0
	if material is ShaderMaterial:
		if skip_shader:
			material = null
		else:
			material.set_shader_parameter("time", time)
			reset_start_time()
	if not skip_particles:
		start_particles()
	if $Sound and not skip_sound:
		$Sound.play()

func _process(delta):
	time += delta
	if material is ShaderMaterial:
		material.set_shader_parameter("time", time)
	if auto_free and time > max_screen_time:
		queue_free()
	
func reset_start_time():
	material.set_shader_parameter("start_time", time)
	
func start_particles():
	for node in get_children():
		if node is GPUParticles2D:
			node = node as GPUParticles2D
			node.emitting = true
