extends Node2D

func _input(_event):
	if Input.is_action_just_pressed("monster_turn"):
		var queue = PriorityQueue.new()
		print("Queue is %s" % queue)
		
