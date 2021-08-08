# Copyright © 2021 Yannick Gingras <ygingras@ygingras.net>

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

""" Cartesian geometry helpers. """

import itertools

def cannon_corners(corner1, corner2):
    """ Return the rectangle defined by the two points as a cannonnical 
    bottom-left and top-right corners rectange.
    """ 
    (x1, y1), (x2, y2) = corner1, corner2
    x1, x2 = sorted((x1, x2))
    y1, y2 = sorted((y1, y2))
    return (x1, y1), (x2, y2)

def rect_interstect(rect1, rect2):
    (r1x1, r1y1), (r1x2, r1y2) = rect1
    (r2x1, r2y1), (r2x2, r2y2) = rect2
    if r2x1 > r1x2 or r2x2 < r1x1:
        return False
    if r2y1 > r1y2 or r2y2 < r1y1:
        return False
    return True

def rect_center(bl, tr):
    (x1, y1), (x2, y2) = bl, tr
    x = x1 + (x2 - x1) // 2
    y = y1 + (y2 - y1) // 2
    return x, y

def iter_tiles(rect):
    (x1, y1), (x2, y2) = rect
    for x in range(x1, x2+1):
        for y in range(y1, y2+1):
            yield (x, y)

def y_sorted(seq):
    """ Return a sequence of (x, y) coords sorted by its y component. """
    return sorted(seq, key=operator.itemgetter(1))

class PolyCont:
    """ A collection of multiple coordinate containers. """
    
    def __init__(self, *conts):
        self._conts = list(conts)

    def __len__(self):
        """ Return the number of top-level containers. """
        return len(self._conts)
        
    def __contains__(self, pos):
        for cont in self._conts:
            if pos in cont:
                return True
        return False

    def __add__(self, other):
        """ Merge two PolyCont instances, returning a new instance. """
        return PolyCont(*(self._conts + other._conts))

    def __getitem__(self, idx):
        """ Access one of the top-level containers. """
        return self._conts[idx]

    def __iter__(self):
        """ Iterate on the top-level containers. """
        return iter(self._conts)

    def items(self):
        """ Iterate on all the leaf-level items stored in the top-level 
        containers as one flat collection. """
        return itertools.chain(*self._conts)

    def append(self, cont):
        """ Append a top-level container. """
        self._conts.append(cont)