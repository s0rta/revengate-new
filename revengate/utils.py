# Copyright © 2022 Yannick Gingras <ygingras@ygingras.net> and contributors

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


class Array:
    """ A 2-dimensional array. 
    
    Data in each cell can be heterogeneous. """

    @classmethod
    def from_list(cls, lst):
        width = len(lst)
        height = len(lst[0])
        arr = cls(width, height)
        for x in range(width):
            for y in range(height):
                arr[x, y] = lst[x][y]
        return arr
    
    def __init__(self, width, height, fill=None):
        self.width = width
        self.height = height
        self.cells = [[fill] * height for i in range(width)]

    def __iter__(self):
        """ Return an iterator for all the elements in no particular order. """
        for col in self.cells:
            for item in col:
                yield item
        
    def __getitem__(self, coord):
        if isinstance(coord, int):
            return self.cells[coord]
        elif isinstance(coord, (tuple, list)):
            x, y = coord
            return self.cells[x][y]

    def __setitem__(self, coord, val):
        x, y = coord
        self.cells[x][y] = val

    def __bool__(self):
        return len(self.cells) > 0 and len(self.cells[0]) > 0

    def pop(self):
        """ Return an element at the end of the array and shrink rows and columns to not 
        leave a void.
        
        Indexing is at your own risk after you start popping.
        """
        if not self.cells:
            return IndexError("Array is empty")
        elem = self.cells[-1].pop()
        if not self.cells[-1]:
            self.cells.pop()
        return elem

    def size(self):
        return (self.width, self.height)

    def transpose(self):
        """ Swap columns and rows in places. """
        self.width, self.height = self.height, self.width
        self.cells = list(map(list, zip(*self.cells)))

    def iter_rows(self):
        return map(list, zip(*self.cells))

    def iter_cols(self):
        return iter(self.cells)


def best(seq, key=None, reverse=False):
    """ Return the highest scoring element of seq.
    
    key: like for sorted()
    reverse: like for sorted() 
    """
    # We could implement this in O(n) with a one-pass for-loop if needed
    return sorted(seq, key=key, reverse=reverse)[-1]
