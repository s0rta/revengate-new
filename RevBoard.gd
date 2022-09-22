extends TileMap
class_name RevBoard

const TILE_SIZE = 32

static func canvas_to_board(coord):
	## Return a coordinate in number of tiles from coord in pixels.
	return Vector2(int(coord.x) / TILE_SIZE,
					int(coord.y) / TILE_SIZE)

static func board_to_canvas(coord):
	## Return a coordinate in pixels to the center of the tile at coord. 
	var half_tile = TILE_SIZE / 2
	return Vector2(coord.x * TILE_SIZE + half_tile, 
					coord.y * TILE_SIZE + half_tile)

func is_walkable(tile_pos:Vector2i):
	## Return whether a tile is walkable for normal actors
	# collision is only specified on phys layer 0
	var tdata = get_cell_tile_data(0, tile_pos)
	var poly = tdata.get_collision_polygons_count(0)
	return poly == 0
