extends Strategy
## Track the hero at every move.
class_name Tracking

func act(actor: Actor):
	var hero = $"/root/Main/Hero"
	var board = $"/root/Main/Board"
	if hero == null or board == null:
		# we're are not in a complete scene
		return null

	var here = RevBoard.canvas_to_board(actor.position)
	var there = RevBoard.canvas_to_board(hero.position)
	var path = board.path(here, there)
	if path != null and path.size() > 1:
		return actor.move_to(path[1])
