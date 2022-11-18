extends Object
##  Utilities for random number generation
class_name Rand

enum Orientation {HORIZONTAL, VERTICAL, RANDOM, LONG_SIDE}

static func rstest(success_rate:float):
	"""	Randon Success Test: return `true` success_rate fraction of the times 
	
	success_rate: in 0..1
	"""
	return randf() <= success_rate

static func rftest(failure_rate:float):
	""" Randon Failure Test: return `true` failure_rate fraction of the times 
	
	failure_rate: in 0..1
	"""
	return randf() > failure_rate
	
static func choice(seq:Array):
	""" Return a random element of seq. """
	var idx = randi_range(0, seq.size()-1)
	return seq[idx]

static func weighted_choice(seq:Array, weights:Array):
	""" Select an element from seq with a bias specified by weights. 
	
	weights: relative bias of each element of seq, must have the same number of 
	elements as seq. For example, to make the first item 3 times as likely to be selected and the 
	second one half as likely, you would pass weights = [3, 0.5, 1, 1 ..., 1].
	"""
	# inspired by the Python implementation of random.choices()
	var cum_weights = [0]
	var tot = 0
	assert(seq.size() == weights.size())
	for w in weights:
		tot += w
		cum_weights.append(tot)
			
	# weighted indexing with a random val
	var val = randf_range(0, tot)
	return seq[cum_weights.bsearch(val) - 1]

static func biased_choice(seq:Array, bias, biased_elem=null):
	""" Select an element from seq with a bias for one of the element. 
	
	bias: how many times is the biased element more likely to be select 
	ex.: 0.5 for half as likely, 2 for twice as likely 
	
	If biased_elem elem is provided and is present in the sequence, it's 
	first occurence will be biased; if it's not in the sequence, no item 
	will receive bias. If biased_elem is not provided, the first element 
	receives the bias. 
	"""
	# inspired by the Python implementation of random.choices()
	
	# find the biased element
	var bias_idx = 0
	if biased_elem != null:
		bias_idx = seq.find(biased_elem)
	
	# compute cumulative weights
	var cum_weights = [0]
	var tot = 0
	for i in range(seq.size()):
		if i == bias_idx:
			tot += bias
		else:
			tot += 1
		cum_weights.append(tot)
			
	# weighted indexing with a random val
	var val = randf_range(0, tot)
	return seq[cum_weights.bsearch(val) - 1]
	
static func pos_in_rect(rect:Rect2i):
	var offset = Vector2i(randi_range(0, rect.size.x-1), 
						randi_range(0, rect.size.y-1))
	return rect.position + offset

static func sub_rect(rect:Rect2i, min_side=1):
	## Return a rectangle that is contained inside rect, likely smaller, 
	## with sides no smaller than min_side.
	var size = Vector2i(randi_range(min_side, rect.size.x), 
						randi_range(min_side, rect.size.y))
	var margin = rect.size - size
	var offset = Vector2i(randi_range(0, margin.x), randi_range(0, margin.y))
	return Rect2i(rect.position + offset, size)					

static func split_rect(rect:Rect2i, orientation, pad=0, min_side=1):
	## Return an array of two rects corresponding to the binary partition of 
	## rect.
	## Return null if rect can't be splip in a way that meets the requirements.
	## orientation: one of Rand.Orientation, including RANDOM
	## pad: free space between the partition
	## min_side: how small the smallest side of a partition be?
	var metric = null
	var min_metric = min_side*2 + pad
	if orientation == Orientation.RANDOM:
		var options = []
		if rect.size.x >= min_metric:
			options.append(Orientation.HORIZONTAL)
		if rect.size.y >= min_metric:
			options.append(Orientation.VERTICAL)
		if options.is_empty():
			return null
		orientation = choice(options)
	elif orientation == Orientation.LONG_SIDE:
		if rect.size.x >= rect.size.y:
			orientation = Orientation.HORIZONTAL
		else:
			orientation = Orientation.VERTICAL
	if orientation == Orientation.HORIZONTAL:
		metric = rect.size.x
	elif orientation == Orientation.VERTICAL:
		metric = rect.size.y
		
	assert(metric >= min_metric)
	var boundary = randi_range(min_side, metric - min_side - pad - 1)
	
	var br1 = null  # bottom-right of first partition
	var tl2 = null  # top-left of second partition
	if orientation == Orientation.HORIZONTAL:
		br1 = rect.position + V.i(boundary, rect.size.y - 1)
		tl2 = rect.position + V.i(boundary + pad + 1, 0)
	elif orientation == Orientation.VERTICAL:
		br1 = rect.position + V.i(rect.size.x - 1, boundary)
		tl2 = rect.position + V.i(0, boundary + pad + 1)
	else: 
		return null
	return [Rect2i(rect.position, br1 - rect.position + Vector2i.ONE), 
			Rect2i(tl2, rect.end - tl2)]  # rect.end is outside the rect!
