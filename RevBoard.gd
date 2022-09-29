extends TileMap
class_name RevBoard

const TILE_SIZE = 32

## PriorityQueue based on distance: dequeing is always with the 
## smallest value.
class DistQueue extends PriorityQueue:
	static func inverse(value):
		## Return the negative of a value. 
		## If value is an Array, return an Array of the negatives if the Array items.
		if value is Array:
			var inv = []
			for item in value:
				inv.append(-item)
			return inv
		else:
			return -value
	
	func _to_string():
		return "<DistQueue %s>" % [heap]
		
	func enqueue(item, dist):
		# var pri = inverse(dist)
		super.enqueue(item, dist)
		
	func peek():
		## Return the distance of the next item to be dequeued.
		var rec = heap[0]
		# return inverse(rec[PriorityQueue.PRIORITY_FIELD])
		return rec[PriorityQueue.PRIORITY_FIELD]

class Matrix:
	var size: Vector2i 
	var cells: Array
	
	func _init(mat_size, default=null):
		if mat_size is Array:
			mat_size = Vector2i(mat_size[0], mat_size[1])
		size = mat_size
		cells = []
		cells.resize(size.y)
		for j in range(size.y):
			cells[j] = []
			cells[j].resize(size.x)
			cells[j].fill(default)
	
	func getv(pos:Vector2i):
		return cells[pos.y][pos.x]
	
	func setv(pos:Vector2i, val):
		cells[pos.y][pos.x] = val

	func _to_string():
		var str = ""
		var row = ""
		var prefix = "["
		var suffix = ""
		for j in range(size.y):
			if j < size.y - 1:
				suffix = ","
			else:
				suffix = "]"
			row = prefix + "["
			for i in range(size.x):
				row += str(cells[j][i])
				if  i != size.x - 1:
					row += ", "
			row += "]" + suffix + "\n"
			str += row
			prefix = " "
		return str
		
	func duplicate():
		var mat = Matrix.new(size)
		for j in range(size.y):
			mat.cells[j] = Array(cells[j])
		return mat
		
	func replace(old_val, new_val):
		for i in range(size.x):
			for j in range(size.y):
				var pos = Vector2i(i, j)
				if getv(pos) == old_val:
					setv(pos, new_val)
		
class BoardMetrics:
	var start: Vector2i
	var dists: Matrix
	var furthest_pos = start
	var furthest_dist = 0
	var prevs = {}
	
	func _init(size:Vector2i, start:Vector2i):
		dists = Matrix.new(size)
		dists.setv(start, 0)
		self.start = start
		self.furthest_pos = start
		self.prevs[start] = null

	func _to_string():
		var mat = dists.duplicate()
		mat.replace(null, " ")
		return mat.to_string()

	func getv(pos:Vector2i):
		return dists.getv(pos)
	
	func setv(pos:Vector2i, val):
		dists.setv(pos, val)
	
	func add_edge(here, there):
		## record that `here` is the optimal previous location to reach `there`.
		## The caller is responsible for knowing that the edge is indeed optimal.
		prevs[there] = here

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
	if tdata == null:
		print("no data for tile_pos=%s!!!" % tile_pos)
	var poly = tdata.get_collision_polygons_count(0)
	return poly == 0

func adjacents(pos:Vector2i, free:bool=true, in_board:bool=true, bbox=null):
	## Return an Array of tiles immediately next to pos. 
	## free: only include tiles that are walkable and unoccupied
	## in_board: only include tiles that are inside the board (edges included)
	if bbox == null and in_board:
		bbox = get_used_rect()
	var tiles = []
	for i in range(-1, 2):
		tiles.append(pos + Vector2i(i, -1))
	for j in range(0, 2):
		tiles.append(pos + Vector2i(1, j))
	for i in range(0, -2, -1):
		tiles.append(pos + Vector2i(i, 1))
	for j in range(0, -1, -1):
		tiles.append(pos + Vector2i(-1, j))
		
	if in_board:
		# TODO: might need adjustment for the bottom and right edges
		tiles = tiles.filter(func(tile): return bbox.has_point(tile))

	if free:
		tiles = tiles.filter(is_walkable)
		
	return tiles

func dist_metrics(start=null, dest=null, max_dist=null):
	## Return distance metrics or all positions accessible from start. 
	## Start is randomly selected if not provided.
	## Stop exploring after reaching `dest` if provided.
	## Do not explore further than `max_dist` if provided. 
	# using the Dijkstra algo
	
	# find our size
	var bbox:Rect2i = get_used_rect()
	assert(bbox.position == Vector2i.ZERO, \
			"make sure the board starts at the origin")
			
	# find the start: randomize if not provided
	if start == null:
		# TODO: pick only walkable starting points
		start = Rand.pos_in_rect(bbox)
	
	var metrics = BoardMetrics.new(bbox.size, start)
	var queue = DistQueue.new()
	var done = {}
	var dist = 0
	var next_dist = null
	queue.enqueue(start, dist)
	var current = null
	while not queue.empty():
		dist = queue.peek()
		current = queue.dequeue()
		if current == dest:
			break  # Done!
		if done.has(current) or dist == max_dist:
			continue  # this position is finalized already

		for pos in adjacents(current, true, true, bbox):
			if done.has(pos):
				continue
			next_dist = metrics.getv(pos)
			if next_dist == null or next_dist > dist+1:
				metrics.setv(pos, dist+1)
				metrics.add_edge(current, pos)
			queue.enqueue(pos, dist+1)
		done[current] = true
	return metrics
	
