extends Node2D

func test_change_board():
	var new_board = $Board.duplicate()
	var builder = BoardBuilder.new(new_board)
	builder.gen_level()

	var bbox = null
	for thing in [$Hero, $Monster, $Monster2]:
		print("moving %s somewhere else" % [thing])
		builder.place(thing, false, null, false, bbox)

	var old_board = $Board
	old_board.replace_by(new_board)
	old_board.queue_free()

func _input(_event):
	if Input.is_action_just_pressed("test"):
		test_change_board()
		
#		var bbox = Rect2i(0, 0, 4, 4)
#		var center = V.i(1, 1)
#		print("Adjacents: %s" % [$Board.adjacents(center, false, true, bbox)])
#		print("Ring:      %s" % [$Board.ring(center, 1, false, true, bbox)])
#		var spiral = $Board.spiral(center, 1, false, true, bbox)
#		# var coords = [spiral.next(), spiral.next()]
#		var coords = []
#		for c in spiral:
#			coords.append(c)
#		print("Spiral:    %s" % [coords])
		
