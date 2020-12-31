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

import heapq
from copy import deepcopy
from enum import IntEnum, auto
from collections import defaultdict

from .actors import Actor

# Only Square tiles are implemented, but being able to switch between Square 
# and Hex would be great.  Hex math is well explained here:
# - https://www.redblobgames.com/grids/hexagons/
# - http://www-cs-students.stanford.edu/~amitp/Articles/Hexagon1.html
# Python packages of interest are:
# - Hexy: coordinate transforms, good for tap events
# - hexutil: Hex.distance and A* implementation

class TileType(IntEnum):
    SOLID_ROCK = auto()
    FLOOR = auto()
    WALL = auto()
    WALL_V = auto()
    WALL_H = auto()
    DOORWAY = auto()

TEXT_TILE = {TileType.SOLID_ROCK:'▓', 
             TileType.FLOOR: '.', 
             TileType.WALL: '░', 
             TileType.WALL_V: '|', 
             TileType.WALL_H: '─', 
             TileType.DOORWAY: '◠'}

WALKABLE = [TileType.FLOOR]


class Queue:
    """ A priority queue. """
    def __init__(self):
        self.elems = []
        
    def push(self, elem):
        heapq.heappush(self.elems, elem)
    
    def pop(self):
        return heapq.heappop(self.elems)


class Map:
    """ The map of a dungeon level. 
    
    Coordinates are the same as OpenGL right-handed: (0, 0) is the bottom 
    left corner.
    """
    def __init__(self, name=None):
        super(Map, self).__init__()
        self.name = name
        self.tiles = []
        self.overlays = []
        self._a_to_pos = {} # actor to position mapping
        self._pos_to_a = {} # position to actor mapping
        
    def size(self):
        """ Return a (width, height) tuple. """
        w = len(self.tiles)
        if w > 0:
            h = len(self.tiles[0])
        else:
            h = 0
        return w, h

    def add_overlay(self, overlay):
        self.overlays.append(overlay)
    
    def remove_overlay(self, overlay):
        self.overlays = [o for o in self.overlays if o != overlay]
    
    def clear_overlays(self):
        self.overlays = []
            
    def distance(self, x1, y1, x2, y2):
        """ Return the grid distance between two points.  
        
        This is not the path length taking obstables into account. """
        # Chebyshev distance (Hex maps will need a different distance metric)
        # This is not the Manhattan disance since we allow diagonal movement.
        return max(abs(x1 - x2), abs(y1 - y2))
    
    def adjacents(self, x, y, free=False):
        """ Return a list of coordinates for tiles adjacent to (x, y).
        
        Map boundaries are checked. 
        If free=True, only tiles availble for moving are returned. 
        """
        tiles = []
        for i in range(-1, 2):
            tiles.append((x+i, y+1))
            tiles.append((x+i, y-1))
        tiles.append((x-1, y))
        tiles.append((x+1, y))
        w, h = self.size()
        tiles = [(x, y) for x, y in tiles if 0<=x<w and 0<=y<h]
        if free:
            tiles = [t for t in tiles if self.is_free(*t)]
        return tiles

    def is_free(self, x, y):
        """ Is the tile at (x, y) free for at actor to step on?"""
        coord = (x, y)
        if self.tiles[x][y] in WALKABLE and coord not in self._pos_to_a:
            return True
        else:
            return False
        
    def _rebuild_path(self, start, stop, seen_map):
        path = [stop]
        current = stop
        while current != start:
            current = seen_map[current]
            path.append(current)
        return reversed(path)

    def path(self, x1, y1, x2, y2):
        """ Find an optimal path going from (x1, y1) to (x2, y2) taking 
        obstacles into account. 
        
        Return the path as a list of (x, y) tuples. """
        # Using the A* algorithm
        start = (x1, y1)
        goal = (x2, y2)
        came_from = {} # a back track map from one point to it's predecessor
        open_q = Queue()
        open_set = {start}
        prev = None
        
        g_scores = {start: 0}
        f_scores = {start: self.distance(*start, *goal)}
        open_q.push((f_scores[start], start))

        current = None
        while open_set:
            score, current = open_q.pop()
            while current not in open_set:
                score, current = open_q.pop()
            open_set.remove(current)
            
            if current == goal:
                return self._rebuild_path(start, goal, came_from)
            for tile in self.adjacents(*current):
                if not self.is_free(*tile) and tile != goal:
                    continue
                g_score = g_scores[current] + self.distance(*current, *tile)
                if tile not in g_scores or g_score < g_scores[tile]:
                    came_from[tile] = current
                    g_scores[tile] = g_score
                    f_scores[tile] = g_score + self.distance(*tile, *goal)
                    open_q.push((f_scores[tile], tile))
                    open_set.add(tile)
        return None

    def find(self, thing):
        """ Return the position of thing if its on the map, None otherwise. """
        if thing in self._a_to_pos:
            return self._a_to_pos[thing]
        return None

    def place(self, thing, x, y):
        """ Put thing on the map at (x, y). """
        pos = (x, y)
        if isinstance(thing, Actor):
            if pos in self._pos_to_a:
                raise ValueError(f"There is already an actor at {pos}!")
            if thing in self._a_to_pos:
                raise ValueError(f"{thing} is already on the map, use"
                                  " Map.move() to change it's position.")
            self._a_to_pos[thing] = pos
            self._pos_to_a[pos] = thing
        else:
            raise ValueError(f"Unsupported type for placing {thing} on the map.")
        
    def move(self, thing, x, y):
        """ Move something already on the map somewhere else.
        
        Speed and obstables are not taken into account. """
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
            
        # overlay actors and objects
        for a, (x, y) in self._a_to_pos.items():
            cols[x][y] = a.char
            
        # overlay extra layers:
        for o in self.overlays:
            for (x, y), thing in o.items():
                cols[x][y] = str(thing) # FIXME: use the text overlay instead

        # transpose and stringify
        lines = []
        for l in zip(*cols):
            lines.append("".join(l))
        return "\n".join(lines)


class MapOverlay:
    """ A sparse overlay to be rendered on top of a map. """
    def __init__(self):
        super(MapOverlay, self).__init__()
        self.tiles = defaultdict(lambda: {}) # keep the same addressing at Map

    def char_at(self, x, y):
        if x in self.tiles:
            if y in self.tiles[x]:
                # TODO: convert to char if TileType
                return self.tiles[x][y]
        return None
    
    def place(self, thing, x, y):
        self.tiles[x][y] = thing
        
    def items(self):
        """ Generator for ((x, y), thing) items of everything inside the 
        overlay. """
        for x in self.tiles:
            for y in self.tiles[x]:
                yield ((x, y), self.tiles[x][y])

    def text_items(self):
        """ Like MapOverlay.items() but everything is converted to text before 
        being returned. """
        raise NotImplementedError()

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
    
