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

## A special effect with both audio and visual components
class_name SpecialEffect extends Node2D

## should the VFX remove itself from the scene tree after flashing
@export var auto_free := true

const MAX_SCREEN_TIME = 5

# not using TIME in the shader(s) because we want to be able to set the effect start time 
# from GDScript
var time: float

func _ready():
	time = 0
	if material is ShaderMaterial:
		material.set_shader_parameter("time", time)
		reset_start_time()
	start_particles()
	$Sound.play()

func _process(delta):
	time += delta
	if material is ShaderMaterial:
		material.set_shader_parameter("time", time)
	if auto_free and time > MAX_SCREEN_TIME:
		queue_free()
	
func reset_start_time():
	material.set_shader_parameter("start_time", time)
	
func start_particles():
	for node in get_children():
		if node is GPUParticles2D:
			node = node as GPUParticles2D
			node.emitting = true
