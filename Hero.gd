@tool
extends Actor

func _ready():
	super()
	state = States.LISTENING

func _input(_event):
	pass

func _unhandled_input(event):
	# TODO: mark as handled
	var move = null
	if state != States.LISTENING:
		return
	
	if Input.is_action_just_pressed("right"):
		move = V.i(1, 0)
	if Input.is_action_just_pressed("left"):
		move = V.i(-1, 0)
	if Input.is_action_just_pressed("up"):
		move = V.i(0, -1)
	if Input.is_action_just_pressed("down"):
		move = V.i(0, 1)
		
	if move:
		ray.enabled = true
		ray.target_position = move * RevBoard.TILE_SIZE
		ray.force_raycast_update()
		if ray.is_colliding():
			print("collision towards %s" % move)
			return
		else:
			print("no colision at %s" % ray.target_position)
		state = States.ACTING
		var anim = self.move_by(move)
		await anim.finished
		print("anim finished")
		finalize_turn()


func act():
	state = States.LISTENING
	print("hero acting...")
	await self.turn_done
		
