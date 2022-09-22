extends Node

# TODO: discover the children

enum States {STOPPED, PROCESSING}
var state = States.STOPPED

var turn = 0

func _input(_event):
	if Input.is_action_just_pressed("run_loop"):
		get_tree().set_input_as_handled()
		await run()

func _ready():
	await run()

func find_actors():
	var actors = []
	var scene = get_parent()
	if scene == null:
		return []
	for node in scene.get_children():
		if node is Actor:
			actors.append(node)
	return actors
	
func run():
	var actors: Array
	state = States.PROCESSING
	while state == States.PROCESSING:
		print("Starting turn %d" % turn)
		actors = find_actors()
		print(actors)
		for actor in actors:
			actor.act()
			#yield(get_tree().create_timer(0.05), "timeout")
		for actor in actors:
			if actor.state != Actor.States.IDLE:
				print("waiting for %s..." % actor)
				await actor.turn_done
				print("done with %s!" % actor)
		turn += 1
	
