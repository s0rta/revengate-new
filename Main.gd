extends Node2D

func _input(_event):
	if Input.is_action_just_pressed("test"):
		var new_board = $Board.duplicate()
		var builder = BoardBuilder.new(new_board)
		builder.test()

		var old_board = $Board
		old_board.replace_by(new_board)
		old_board.queue_free()
#		var rects = [Rect2i(0, 0, 10, 10), 
#				Rect2i(1, 1, 10, 10), 
#				Rect2i(0, 0, 20, 6), 
#				Rect2i(1, 1, 6, 20), 
#		]
#		for rect in rects:
#			var split = Rand.split_rect(rect, Rand.Orientation.RANDOM, 1, 2)
#			print("Split of %s (end:%s) is %s" % [rect, rect.end, split])
#
