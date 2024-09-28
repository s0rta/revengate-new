# Copyright © 2022–2024 Yannick Gingras <ygingras@ygingras.net> and contributors

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

##  Utilities for random number generation
class_name Rand extends Object

enum Orientation {HORIZONTAL, VERTICAL, RANDOM, LONG_SIDE}

static func rstest(success_rate:float):
	## Randon Success Test: return `true` success_rate fraction of the times
	## success_rate: in 0..1
	# Because both 0.0 and 1.0 are likely `randf()` outcomes, we need a special case on one of
	# those sides to make sure that 0.0 fails all the times and that 1.0 always succeeds.
	if success_rate == 0.0:
		return false
	else:
		return randf() <= success_rate

static func rftest(failure_rate:float):
	## Randon Failure Test: return `true` failure_rate fraction of the times
	## failure_rate: in 0..1
	# Because both 0.0 and 1.0 are likely `randf()` outcomes, we need a special case on one of
	# those sides to make sure that 1.0 fails all the times and that 0.0 always succeeds.
	if failure_rate == 1.0:
		return false
	else:
		return randf() > failure_rate

static func linear_prob_test(val, start, end) -> bool:
	## Return return true/false weighted by how far val is in [start..end].
	## val <= start is always false
	## val >= end is always true
	var slope:float = 1.0 / (end-start)
	var weight = 1.0 * (val - start) * slope
	weight = clampf(weight, 0.0, 1.0)
	return rstest(weight)

static func choice(seq:Array):
	## Return a random element of seq.
	var idx = randi_range(0, seq.size()-1)
	return seq[idx]

static func weighted_choice(seq:Array, weights:Array):
	## Select an element from seq with a bias specified by weights.
	##
	## weights: relative bias of each element of seq, must have the same number of
	## elements as seq. For example, to make the first item 3 times as likely to be selected and the
	## second one half as likely, you would pass weights = [3, 0.5, 1, 1 ..., 1].

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
	## Select an element from seq with a bias for one of the element.
	##
	## bias: how many times is the biased element more likely to be select
	## ex.: 0.5 for half as likely, 2 for twice as likely
	##
	## If biased_elem elem is provided and is present in the sequence, it's
	## first occurence will be biased; if it's not in the sequence, no item
	## will receive bias. If biased_elem is not provided, the first element
	## receives the bias.
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

static func rect(rects, valid_pred=null):
	## Return the index of one of the rectangle in `rects`.
	## valid_pred: if provided, only rectangle that are true for it are considered.
	## The selection is biased towards selecting larger rectangles.
	## Return `null` if no element in `rects` is valid.
	var areas = []
	var indices = []
	var size:Vector2i
	for i in rects.size():
		size = rects[i].size
		if valid_pred != null and not valid_pred.call(rects[i]):
			continue  # ignore invalid rectangles
		indices.append(i)
		areas.append(rects[i].get_area())
	if indices.is_empty():
		return null
	return Rand.weighted_choice(indices, areas)

static func coord_in_rect(rect:Rect2i):
	var offset = Vector2i(randi_range(0, rect.size.x-1),
						randi_range(0, rect.size.y-1))
	return rect.position + offset

static func coord_on_rect_perim(rect: Rect2i, region=null):
	## Return a coordinate along the perimeter of `rect`. Corners are excluded.
	## region: if supplied, only this side is considered.
	if region == null or region == Consts.REG_CENTER:
		region = choice([Consts.REG_NORTH, Consts.REG_SOUTH, Consts.REG_WEST, Consts.REG_EAST])

	# We pick a random coord inside the rect, then project it against one of the
	# sides accoding to the region.
	# rect.end() is outside the rect, so we have to subtract 1 from it
	var coord = coord_in_rect(Geom.inner_rect(rect))
	if region == Consts.REG_NORTH:
		return Vector2i(coord.x, rect.position.y)
	elif region == Consts.REG_SOUTH:
		return Vector2i(coord.x, rect.end.y-1)
	elif region == Consts.REG_WEST:
		return Vector2i(rect.position.x, coord.y)
	elif region == Consts.REG_EAST:
		return Vector2i(rect.end.x-1, coord.y)
	else:
		assert(false, "Unknown region: %s" % region)

static func sub_rect(rect:Rect2i, min_size:=Vector2i.ONE):
	## Return a rectangle that is contained inside rect, likely smaller.
	## `min_size`: The rect is at least that big.
	assert(rect.size >= min_size, "%s is too small to accomodate a sub_rect of size=%s" % [rect, min_size])
	var size = Vector2i(randi_range(min_size.x, rect.size.x),
						randi_range(min_size.y, rect.size.y))
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

	assert(metric >= min_metric,
			"%s is too small to be split with min_side=%s and pad=%s" % [rect, min_side, pad])

	# a line just beyond the first partition
	var boundary = randi_range(min_side, metric - min_side - pad)

	var r1size = null  # size of the first rect
	var r2size = null  # size of the second rect
	var tl2 = null  # top-left of second partition
	if orientation == Orientation.HORIZONTAL:
		r1size = Vector2i(boundary, rect.size.y)
		r2size = Vector2i(metric - boundary - pad, rect.size.y)
		tl2 = rect.position + Vector2i(boundary + pad, 0)
	elif orientation == Orientation.VERTICAL:
		r1size = Vector2i(rect.size.x, boundary)
		r2size = Vector2i(rect.size.x, metric - boundary - pad)
		tl2 = rect.position + Vector2i(0, boundary + pad)
	else:
		return null
	return [Rect2i(rect.position, r1size),
			Rect2i(tl2, r2size)]
