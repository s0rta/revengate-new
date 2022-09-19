extends Actor

func _ready():
	state = States.LISTENING

func _input(event):
	pass

func _unhandled_input(event):
	# TODO: see if event is the actual action, mark as handled
	# TODO: lock input while anims are in progress
	var move = null
	if state != States.LISTENING:
		return
	
	if Input.is_action_just_pressed("right"):
		move = Vector2(1, 0)
	if Input.is_action_just_pressed("left"):
		move = Vector2(-1, 0)
	if Input.is_action_just_pressed("up"):
		move = Vector2(0, -1)
	if Input.is_action_just_pressed("down"):
		move = Vector2(0, 1)
		
	if move:
		print_tree_pretty()
		ray.enabled = true
		ray.cast_to = move * TILE_SIZE
		ray.force_raycast_update()
		if ray.is_colliding():
			print("collision towards %s" % move)
			return
		state = States.ACTING
		get_tree().set_input_as_handled()
		var anim = self.move_by(move)
		yield(anim, "finished")
		print("anim finished")
		finalize_turn()


func act():
	state = States.LISTENING
	print("hero acting...")
	yield(self, "turn_done")
		
