extends Strategy
class_name Tracking

""" Track the hero at every move. """

func act(actor: Actor):
	var hero = $"/root/Main/Hero"
	var dir = hero.position - actor.position
	dir = Vector2(dir.x, 0).normalized() + Vector2(0, dir.y).normalized()
	return actor.move_by(dir)
