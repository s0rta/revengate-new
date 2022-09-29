extends Node2D

func _input(_event):
	if Input.is_action_just_pressed("test"):
		var metrics = $Board.dist_metrics(Vector2i(5, 3))
		print("Metrics: \n%s" % metrics)
