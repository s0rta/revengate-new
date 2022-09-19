extends Area2D
class_name Actor
signal turn_done
const TILE_SIZE = 32

enum States {
	IDLE,
	LISTENING,
	ACTING,
}

var state = States.IDLE
var ray := RayCast2D.new()

static func canvas_to_board(coord):
	""" Return a coordinate in number of tiles from coord in pixels. """
	return Vector2(int(coord.x) / TILE_SIZE,
				   int(coord.y) / TILE_SIZE)	

static func board_to_canvas(coord):
	""" Return a coordinate in pixels to the center of the tile at coord. """
	var half_tile = TILE_SIZE / 2
	return Vector2(coord.x * TILE_SIZE + half_tile, 
				   coord.y * TILE_SIZE + half_tile)	

func _ready():
	ray.name = "Ray"
	add_child(ray)
	ray.collide_with_areas = true

func move_by(tile_vect):
	""" Move by the specified number of tiles from the current position. 
	
	The move is animated, return the animation.
	"""
	var new_pos = canvas_to_board(position) + tile_vect
	return move_to(new_pos)
	
func move_to(board_coord):
	""" Move to the specified board coordinate in number of tiles from the 
	origin. 
	
	The move is animated, return the animation.
	"""
	var scene = get_tree()
	var anim = scene.create_tween()
	anim.tween_property(self, "position", board_to_canvas(board_coord), .2)
	return anim
	
func finalize_turn():
	inspect_tile()
	state = States.IDLE
	emit_signal("turn_done")
	
func inspect_tile():
	""" Return information about the tile where the actor currently is. """
	var map : TileMap = $"/root/Main/TileMap"
	print("a < b: %s" % bool([1, 2] < [1, 1]))
	if map != null:
		var mpos = map.world_to_map(position)
		var cell = map.get_cellv(mpos)
		var name = map.tile_set.tile_get_name(cell)
		var nb_shapes = map.tile_set.tile_get_shape_count(cell)
		print("cell info at %s: '%s' %s" % [mpos, name, nb_shapes])
