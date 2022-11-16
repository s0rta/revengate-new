@tool
extends Area2D
class_name Actor
signal turn_done

enum States {
	IDLE,
	LISTENING,
	ACTING,
}

var state = States.IDLE
var ray := RayCast2D.new()
var dest  # keep track of where we are going while animations are running 

func _ready():
	ray.name = "Ray"
	add_child(ray)
	ray.collide_with_areas = true

func _get_configuration_warnings():
	var warnings = []
	if name != "Hero" and find_children("", "Strategy").is_empty():
		update_configuration_warnings()
		warnings.append("Actor's can't act without a strategy.")
	return warnings

func reset_dest():
	dest = null

func get_board_pos():
	## Return the board position occupied by the actor.
	## If the actor is currently moving, return where it's expected to be at the
	## end of the turn.
	if dest != null:
		return dest
	else:
		return RevBoard.canvas_to_board(position)

func place(board_coord):
	## Place the actor at the specific coordinate without animations.
	## No tests are done to see if board_coord is a suitable location.
	if state == States.ACTING:
		await self.turn_done
	position = RevBoard.board_to_canvas(board_coord)

func move_by(tile_vect):
	## Move by the specified number of tiles from the current position. 
	## The move is animated, return the animation.
	var new_pos = RevBoard.canvas_to_board(position) + tile_vect
	return move_to(new_pos)
	
func move_to(board_coord):
	## Move to the specified board coordinate in number of tiles from the 
	## origin. 
	## The move is animated, return the animation.
	var scene = get_tree()
	var anim := scene.create_tween()
	var cpos = RevBoard.board_to_canvas(board_coord)
	anim.tween_property(self, "position", cpos, .2)
	dest = board_coord
	anim.finished.connect(reset_dest, CONNECT_ONE_SHOT)
	return anim
	
func finalize_turn():
	inspect_tile()
	state = States.IDLE
	emit_signal("turn_done")
	
func inspect_tile():
	## Return information about the tile where the actor currently is.
	var board : RevBoard = $"/root/Main/Board"
	if board != null:
		var tpos = RevBoard.canvas_to_board(position)
		var walkable = board.is_walkable(tpos)
		print("cell info at %s: %s" % [tpos, walkable])
