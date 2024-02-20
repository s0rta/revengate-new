
## A minimum heapqueue optimized for Vector2i entried and integer distances.
class_name DistQueue2i extends RefCounted

class Entry:
	var coord: Vector2i
	var dist: int
	
	func _init(coord_:Vector2i, dist_:int):
		coord = coord_
		dist = dist_
	
var heap : Array[Entry] = []

func enqueue(coord:Vector2i, dist:int):
	var entry = Entry.new(coord, dist)
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
		if entry.dist < parent.dist:
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
		if rightpos < endpos and not heap[childpos].dist < heap[rightpos].dist:
			childpos = rightpos
		# swap the smaller child up
		heap[pos] = heap[childpos]
		pos = childpos
		childpos = (pos << 1) + 1
	# The leaf at pos is empty now.  Put newitem there, and bubble it up
	# to its final resting place (by sifting its parents down).
	heap[pos] = entry
	_siftdown(startpos, pos)
