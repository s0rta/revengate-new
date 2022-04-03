# Copyright © 2022 Yannick Gingras <ygingras@ygingras.net>

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
