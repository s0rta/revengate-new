extends Node2D

func _input(_event):
	if Input.is_action_just_pressed("monster_turn"):
		$Monster.act()
		get_tree().set_input_as_handled()
