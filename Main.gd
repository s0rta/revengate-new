extends Node2D

func _input(_event):
	if Input.is_action_just_pressed("test"):
		print("time: %02d" % 4)
		var start = Vector2i(5, 3)
		var dest = V.i(22, 14)
		var metrics = $Board.dist_metrics(start)
		print("Dijkstra Metrics: \n%s" % metrics)
		var path = metrics.path(dest)
		print("path(%d): %s" % [path.size(), path])

		metrics = $Board.astar_metrics(start, dest)
		print("Dijkstra Metrics: \n%s" % metrics)
		path = metrics.path(dest)
		print("path(%d): %s" % [path.size(), path])

