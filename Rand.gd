extends Object
class_name Rand

""" Utilities for random number generation """

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
	var idx = int(rand_range(0, seq.size()))
	return seq[idx]

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
	var val = rand_range(0, tot)
	return seq[cum_weights.bsearch(val) - 1]
	
