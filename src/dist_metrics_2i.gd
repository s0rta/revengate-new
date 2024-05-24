# Copyright © 2024 Yannick Gingras <ygingras@ygingras.net> and contributors

# This file is part of Revengate.

# Revengate is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Revengate is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with Revengate.  If not, see <https://www.gnu.org/licenses/>.

## A container to hold distance metrics of cells addressed by Vector2i.
class_name DistMetrics2i extends RefCounted

var start: Vector2i
var dest: Vector2i
var dists: Matrix2i
var furthest_coord := Consts.COORD_INVALID
var furthest_dist := 0
var prevs := {}

class Matrix2v:
	## A 2 dimentional array of Variants that can be indexed with Vector2i

	var size: Vector2i 
	var cells: Array
	var default = null

	func _init(mat_size:Vector2i, default_=null):
		size = mat_size
		default = default_
		cells = []
		cells.resize(size.x * size.y)
		cells.fill(default)
	
	func getv(pos:Vector2i):
		return cells[pos.y*size.x + pos.x]
	
	func setv(pos:Vector2i, val):
		cells[pos.y*size.x + pos.x] = val

	func pad(width=null):
		## Pad all entries to make them `width` long char fields.
		## `width`: match the widest field if not provided
		if width == null:
			width = 0
			var str = ""
			for val in cells:
				if val is String:
					str = val
				else:
					str = "%s" % [val]
				if str.length() > width:
					width = str.length()

		for i in len(cells):
			cells[i] = "%*s" % [width, cells[i]]					

	func duplicate():
		var mat = Matrix2v.new(size)
		mat.cells.assign(cells)
		return mat

	func replace(old_val, new_val):
		for i in len(cells):
			if cells[i] == old_val:
				cells[i] = new_val

class Matrix2i:
	## A 2 dimentional array of ints that can be indexed with Vector2i
	
	var size: Vector2i 
	var cells: Array[int]
	var default: int
	
	func _init(mat_size:Vector2i, default_:=-1):
		size = mat_size
		default = default_
		cells = []
		cells.resize(size.x * size.y)
		cells.fill(default)
	
	func getv(pos:Vector2i) -> int:
		return cells[pos.y*size.x + pos.x]
	
	func setv(pos:Vector2i, val:int):
		cells[pos.y*size.x + pos.x] = val

	func to_matv() -> Matrix2v:
		var mat = Matrix2v.new(size)
		mat.cells.assign(cells)
		return mat

func _init(size:Vector2i, start_:Vector2i, dest_:=Consts.COORD_INVALID):
	start = start_
	dest = dest_
	dists = Matrix2i.new(size, -1)
	dists.setv(start, 0)
	furthest_coord = start
	prevs[start] = Consts.COORD_INVALID

func _to_string() -> String:
	var mat = dists.to_matv()
	mat.replace(-1, "")
	mat.pad()
	return _mat_to_string(mat)

static func _mat_to_string(mat) -> String:
	var str = ""
	var row = ""
	var prefix = "["
	var suffix = ""
	for j in range(mat.size.y):
		if j < mat.size.y - 1:
			suffix = ","
		else:
			suffix = "]"
		row = prefix + "["
		for i in range(mat.size.x):
			row += str(mat.getv(Vector2i(i, j)))
			if  i != mat.size.x - 1:
				row += ", "
		row += "]" + suffix + "\n"
		str += row
		prefix = " "
	return str

func getv(coord:Vector2i) -> int:
	return dists.getv(coord)

func setv(coord:Vector2i, val:int):
	if val > furthest_dist:
		furthest_coord = coord
		furthest_dist = val
	dists.setv(coord, val)

func has(coord:Vector2i):
	return dists.getv(coord) != dists.default

func all_coords():
	## Return an array of all coordinates with a recorded distance
	## 0-dist(s) is included
	var coords = []
	var idx := 0
	for j in range(dists.size.y):
		for i in range(dists.size.x):
			# inline version of `has(Vector2i(i, j))`
			if dists.cells[idx] != dists.default:
				coords.append(Vector2i(i, j))
			idx += 1
	return coords

func all_dists():
	## Return an array of all recorded distances in the same order as all_coords()
	var used_dists = []
	var dist:int
	var idx := 0
	for j in range(dists.size.y):
		for i in range(dists.size.x):
			# inline version of `dist = dists.getv(Vector2i(i, j))`
			dist = dists.cells[idx]
			if dist != dists.default:
				used_dists.append(dist)
			idx += 1
	return used_dists

func add_edge(here:Vector2i, there:Vector2i):
	## record that `here` is the optimal previous location to reach `there`.
	## The caller is responsible for knowing that the edge is indeed optimal.
	prevs[there] = here

func path(to=null):
	## Return an Array of coordinates going from `self.start` to `to`.
	## Use `self.dest` if `to` is not provided.
	## `start` and `to` are included in the array.
	var dest
	if to == null:
		assert(self.dest != null, \
				"Make sure we were originally passed a destination.")
		dest = self.dest
	else:
		dest = to
	if dists.getv(dest) == -1:
		return null
	var path = []
	var current = dest
	while current != Consts.COORD_INVALID:
		path.append(current)
		current = prevs.get(current)
		assert(current != null)
	if path[-1] != start:
		return null
	else:
		path.reverse()
		return path

func ddump_path(to=null):
	var mat = dists.to_matv()
	mat.replace(-1, "")
	mat.pad()
	var path_steps = path(to)
	for step in path_steps:
		mat.setv(step, Utils.colored(mat.getv(step)))
	print(mat.to_string())
