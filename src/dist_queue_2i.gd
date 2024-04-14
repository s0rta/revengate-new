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

## A minimum heapqueue optimized for Vector2i entried and integer distances.
# This impementation is highly inspired by the Python heapq module.
class_name DistQueue2i extends RefCounted

class Entry:
	var coord: Vector2i
	var dist: int
	var tie_breaker: Array[int]
	
	func _init(coord_:Vector2i, dist_:int, tie_breaker_:Array[int]=[]):
		coord = coord_
		dist = dist_
		tie_breaker = tie_breaker_

	func _to_string():
		return "<Entry %s %s %s>" % [coord, dist, tie_breaker]
	
var heap : Array[Entry] = []

func enqueue(coord:Vector2i, dist:int, tie_breaker:Array[int]=[]):
	var entry = Entry.new(coord, dist, tie_breaker)
	heap.append(entry)
	_siftdown(0, len(heap)-1)
	
func dequeue() -> Entry:
	## Return the minimal entry and restore the heap invariant
	var tail_entry:Entry = heap.pop_back()

	if not heap.is_empty():
		var min_entry:Entry = heap[0]
		heap[0] = tail_entry
		_siftup(0)
		return min_entry
	return tail_entry

func peek() -> Entry:
	## Return the minimal entry without removing it from the heap.
	return heap[0]

func is_empty() -> bool:
	return heap.is_empty()

func _siftdown(startpos:int, pos:int):
	## push a leaf to its final position
	var entry:Entry = heap[pos]
	# walk up towards the root, swap further entries along the way
	while pos > startpos:
		var parentpos:int = (pos - 1) >> 1
		var parent:Entry = heap[parentpos]
		if (entry.dist < parent.dist 
				or entry.dist == parent.dist and entry.tie_breaker < parent.tie_breaker):
			heap[pos] = parent
			pos = parentpos
			continue
		break
	heap[pos] = entry

func _siftup(pos:int):
	var endpos:int = len(heap)
	var startpos := pos
	var entry:Entry = heap[pos]

	# go towards a leaf, swapping closer entries along the way
	var childpos:int = (pos << 1) + 1    # leftmost child position
	var rightpos:int
	while childpos < endpos:
		# Set childpos to index of smaller child.
		rightpos = childpos + 1
		if (rightpos < endpos 
			and not (heap[childpos].dist < heap[rightpos].dist 
						or (heap[childpos].dist == heap[rightpos].dist 
							and heap[childpos].tie_breaker < heap[rightpos].tie_breaker))):
			childpos = rightpos
		# swap the smaller child up
		heap[pos] = heap[childpos]
		pos = childpos
		childpos = (pos << 1) + 1
	# The leaf at pos is empty now.  Put newitem there, and bubble it up
	# to its final resting place (by sifting its parents down).
	heap[pos] = entry
	_siftdown(startpos, pos)

func ddump():
	var q = DistQueue2i.new()
	q.heap = heap.duplicate()
	var entries = []
	while not q.is_empty():
		entries.append(q.dequeue())
	print(entries)
