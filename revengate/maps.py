# Copyright © 2020 Yannick Gingras <ygingras@ygingras.net>

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

""" Maps and movement. """

from copy import deepcopy
from enum import IntEnum, auto
from .actors import Actor

class TileType(IntEnum):
    SOLID_ROCK = auto()
    FLOOR = auto()
    WALL = auto()
    WALL_V = auto()
    WALL_H = auto()
    DOORWAY = auto()

TEXT_TILE = {TileType.SOLID_ROCK: '▧', 
             TileType.FLOOR: '.', 
             TileType.WALL: '□', 
             TileType.WALL_V: '|', 
             TileType.WALL_H: '─', 
             TileType.DOORWAY: '◠'}

class Map:
    """ The map of a dungeon level. 
    
    Coordinates are the same as OpenGL right-handed: (0, 0) is the bottom 
    left corner.
    """
    def __init__(self, name=None):
        super(Map, self).__init__()
        self.name = name
        self.tiles = []
        self._a_to_pos = {} # actor to position mapping
        self._pos_to_a = {} # position to actor mapping

    def place(self, thing, x, y):
        if isinstance(thing, Actor):
            self._a_to_pos[thing] = (x, y)
            self._pos_to_a[(x, y)] = thing
        else:
            raise ValueError(f"Unsupported type for placing {thing} on the map.")
        
    def move(self, thing, x, y):
        if thing in self._a_to_pos:
            del self._pos_to_a[self._a_to_pos[thing]]
            self._pos_to_a[(x, y)] = thing
            self._a_to_pos[thing] = (x, y)
        else:
            raise ValueError(f"{thing} is not on the current map.")
    
    def to_text(self):
        """ Return a Unicode render of the map suitable for display in a 
        terminal."""
        
        # Convert to text
        cols = []
        for col in self.tiles:
            cols.append([TEXT_TILE[t] for t in col])
            
        # overlay actors and stuff
        for a, (x, y) in self._a_to_pos.items():
            cols[x][y] = a.char

        # transpose and stringify
        lines = []
        for l in zip(*cols):
            lines.append("".join(l))
        return "\n".join(lines)


class Builder:
    """ Builder for map features. """
    def __init__(self, map):
        super(Builder, self).__init__()
        self.map = map
    
    def _cannon_corners(self, x1, y1, x2, y2):
        """ Return the rectangle defined by the two points as a cannonnical 
        bottom-left and top-right corners rectange.
        """ 
        x1, x2 = sorted((x1, x2))
        y1, y2 = sorted((y1, y2))
        return x1, y1, x2, y2
    
    def init(self, width, height, fill=TileType.SOLID_ROCK):
        self.map.tiles = [[fill]*height for i in range(width)]
        
    def room(self, x1, y1, x2, y2, walls=False):
        x1, y1, x2, y2 = self._cannon_corners(x1, y1, x2, y2)
        if walls:
            for x in range(x1, x2+1):
                self.map.tiles[x][y1] = TileType.WALL
                self.map.tiles[x][y2] = TileType.WALL
            for y in range(y1+1, y2):
                self.map.tiles[x1][y] = TileType.WALL
                self.map.tiles[x2][y] = TileType.WALL
            x1, y1, x2, y2 = x1+1, y1+1, x2-1, y2-1

        for x in range(x1, x2+1):
            for y in range(y1, y2+1):
                self.map.tiles[x][y] = TileType.FLOOR

def main():
    map = Map()
    builder = Builder(map)
    builder.init(40, 20)
    builder.room(20, 5, 5, 15, True)
    print(map.to_text())


if __name__ == "__main__":
    main()
    
