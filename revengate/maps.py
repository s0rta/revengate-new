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
import random
from copy import deepcopy
from enum import IntEnum, auto
from collections import defaultdict

from .actors import Actor
from .items import Item, ItemCollection

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
SEE_THROUGH = [TileType.FLOOR, TileType.DOORWAY]

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
        self._i_to_pos = {} # item to position
        # position to items
        self._pos_to_i = defaultdict(lambda:ItemCollection()) 

    def size(self):
        """ Return a (width, height) tuple. """
        w = len(self.tiles)
        if w > 0:
            h = len(self.tiles[0])
        else:
            h = 0
        return w, h

    def iter_tiles(self):
        """ Return an iterator for ((x, y), TileType) pairs. """
        w, h = self.size()
        for x in range(w):
            for y in range(h):
                yield ((x, y), self.tiles[x][y])

    def iter_actors(self):
        """ Return an iterator for ((x, y), actor) pairs. """
        for a, (x, y) in self._a_to_pos.items():
            yield ((x, y), a)

    def iter_items(self):
        """ Return an iterator for ((x, y), stack) pairs. 
        
        Only tripplets for non-empty item stacks are returned. """
        for (x, y), stack in self._pos_to_i.items():
            if stack:
                yield ((x, y), stack)

    def iter_overlays(self):
        ...

    def add_overlay(self, overlay):
        self.overlays.append(overlay)
    
    def remove_overlay(self, overlay):
        self.overlays = [o for o in self.overlays if o != overlay]
    
    def clear_overlays(self):
        self.overlays = []
        
    def all_actors(self):
        """ Return a list of all actors known to be on the map. """
        return self._a_to_pos.keys()
            
    def distance(self, pos1, pos2):
        """ Return the grid distance between two points.  
        
        This is not the path length taking obstables into account. """
        # Chebyshev distance (Hex maps will need a different distance metric)
        # This is not the Manhattan distance since we allow diagonal movement.
        x1, y1 = pos1
        x2, y2 = pos2
        return max(abs(x1 - x2), abs(y1 - y2))
    
    def _ring(self, center, radius=1, free=False, shuffle=False):
        """ Return a list of coords defining a ring with the given centre.  
        
        The shape is a square for square tiles and a hex for hex tiles."""
        x, y = center
        w, h = self.size()

        tiles = []
        for i in range(max(0, x-radius), min(x+radius+1, w)):
            if y >= radius:
                tiles.append((i, y-radius))
            if y+radius < h:
                tiles.append((i, y+radius))

        for j in range(max(0, y-radius+1), min(y+radius, h)):
            if x >= radius:
                tiles.append((x-radius, j))
            if x+radius < w:
                tiles.append((x+radius, j))

        if shuffle:
            random.shuffle(tiles)

        if free:
            tiles = [t for t in tiles if self.is_free(t)]
        
        return tiles        
    
    def adjacents(self, pos, free=False, shuffle=False):
        """ Return a list of coordinates for tiles adjacent to pos=(x, y).
        
        Map boundaries are checked. 
        If free=True, only tiles availble for moving are returned. 
        """
        return self._ring(pos, 1, free, shuffle)

    def _nearby_tiles(self, pos, free=False, shuffle=False):
        """ Generate a stream of tiles near pos, progressively further until 
        the whole map has been returned. 
        
        If free=True, the tile can allow an actor to step on.
        """
        w, h = self.size()
        for rad in range(1, max(w, h)):
            tiles = self._ring(pos, rad, free=free, shuffle=shuffle)
            for t in tiles:
                yield t

    def random_tile(self, free):
        """ Return a random tile (x, y) coordinate. 
        
        If free=True, the tile can allow an actor to step on.
        Raise a RuntimeError if no suitable tile can be found. """
        # Fully random attempts a few times, then we systematically explore all
        # the tile if we still haven't found one
        w, h = self.size()
        for i in range(5):
            x, y = random.randrange(w), random.randrange(h)
            if free:
                if self.is_free((x, y)):
                    return (x, y)
            else: 
                return (x, y)
        # Still no luck, so we spiral around the last attempt until we have 
        # tried everything on the map.
        tiles = self._nearby_tiles((x, y), free=free, shuffle=True)
        if tiles:
            return next(iter(tiles))
        else:
            raise RuntimeError("Can't find a free tile on the map.  It appears"
                               " to be completely full!")

    def is_free(self, pos):
        """ Is the tile at pos=(x, y) free for a nactor to step on?"""
        x, y = pos
        if self.tiles[x][y] in WALKABLE and pos not in self._pos_to_a:
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

    def path(self, start, goal):
        """ Find an optimal path going from (x1, y1) to (x2, y2) taking 
        obstacles into account. 
        
        Return the path as a list of (x, y) tuples. """
        # Using the A* algorithm
        came_from = {} # a back track map from one point to it's predecessor
        open_q = Queue()
        open_set = {start}
        prev = None
        
        g_scores = {start: 0}
        f_scores = {start: self.distance(start, goal)}
        open_q.push((f_scores[start], start))

        current = None
        while open_set:
            score, current = open_q.pop()
            while current not in open_set:
                score, current = open_q.pop()
            open_set.remove(current)
            
            if current == goal:
                return self._rebuild_path(start, goal, came_from)
            for tile in self.adjacents(current):
                if not self.is_free(tile) and tile != goal:
                    continue
                g_score = g_scores[current] + self.distance(current, tile)
                if tile not in g_scores or g_score < g_scores[tile]:
                    came_from[tile] = current
                    g_scores[tile] = g_score
                    f_scores[tile] = g_score + self.distance(tile, goal)
                    open_q.push((f_scores[tile], tile))
                    open_set.add(tile)
        return None
    
    def line_of_sight(self, pos1, pos2):
        """ Return a list of tile in the line of sight between pos1 and pos2 
        or None if the direct path is visibly obstructed. """
        steps = []
        nb_steps = self.distance(pos1, pos2) + 1
        mult = max(1, nb_steps - 1)
        # move to continuous coords from the center of the tiles
        x1, y1, x2, y2 = (c+0.5 for c in pos1 + pos2) 
        for i in range(nb_steps):
            x = int(((mult-i)*x1 + i*x2) / mult)
            y = int(((mult-i)*y1 + i*y2) / mult)
            if self.tiles[x][y] in SEE_THROUGH:
                steps.append((x, y))
            else:
                return None
        return steps

    def find(self, thing):
        """ Return the position of thing if its on the map, None otherwise. """
        if thing in self._a_to_pos:
            return self._a_to_pos[thing]
        elif thing in self._i_to_pos:
            return self._i_to_pos[thing]
        return None

    def place(self, thing, pos=None, fallback=False):
        """ Put thing on the map at pos=(x, y). 
        If pos is not not supplied, a random position is selected. 
        If fallback=True, a nearby space is selected when pos is not available.
        """
        if thing in self._a_to_pos or thing in self._i_to_pos:
            raise ValueError(f"{thing} is already on the map, use Map.move()" 
                             " to change it's position.")
        if pos is None:
            pos = self.random_tile(free=True)
        if isinstance(thing, Actor):
            if pos in self._pos_to_a:
                if fallback:
                    tiles = self._nearby_tiles(pos, free=True, shuffle=True)
                    if tiles:
                        pos = next(iter(tiles))
                    else:
                        raise RuntimeError("The map appears to be full!")
                else:
                    raise ValueError(f"There is already an actor at {pos}!")
            self._a_to_pos[thing] = pos
            self._pos_to_a[pos] = thing
        elif isinstance(thing, Item):
            self._i_to_pos[thing] = pos
            self._pos_to_i[pos].append(thing)
        else:
            raise ValueError(f"Unsupported type for placing {thing} on the map.")

    def remove(self, thing):
        """ Remove something from the map."""
        if thing in self._a_to_pos:
            pos = self._a_to_pos[thing]
            del self._pos_to_a[pos]
            del self._a_to_pos[thing]
        elif thing in self._i_to_pos:
            pos = self._a_to_pos[thing]
            self._pos_to_i.remove(pos)
            del self._i_to_pos[thing]
        else:
            raise ValueError(f"{thing} is not on the current map.")
        
    def move(self, thing, there):
        """ Move something already on the map somewhere else.
        
        Speed and obstables are not taken into account. """
        if thing in self._a_to_pos:
            del self._pos_to_a[self._a_to_pos[thing]]
            self._pos_to_a[there] = thing
            self._a_to_pos[thing] = there
        elif thing in self._i_to_pos:
            self._pos_to_i.remove(self._a_to_pos[thing])
            self._pos_to_i[there].append(thing)
            self._i_to_pos[thing] = there
        else:
            raise ValueError(f"{thing} is not on the current map.")
    
    def to_text(self):
        """ Return a Unicode render of the map suitable for display in a 
        terminal."""
        
        # Convert to text
        #  not using iter_tiles() in order to take advantage of or using the 
        #  same nested list format
        cols = []
        for col in self.tiles:
            cols.append([TEXT_TILE[t] for t in col])
            
        # overlay actors and objects
        for (x, y), stack in self.iter_items():
            cols[x][y] = stack.char
        for (x, y), a in self.iter_actors():
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
    
    def place(self, thing, pos):
        x, y = pos
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
    builder.room(5, 5, 35, 15, True)
    print(map.to_text())
    for i in range(10):
        x1, y1 = random.randrange(5, 35), random.randrange(5, 15)
        x2, y2 = random.randrange(5, 35), random.randrange(5, 15)
        los = map.line_of_sight((x1, y1), (x2, y2))
        if los:
            overlay = MapOverlay()
            for c in los[1:-1]:
                overlay.place('x', c)
            overlay.place('@', (x1, y1))
            overlay.place('d', (x2, y2))
            map.add_overlay(overlay)
            print(map.to_text())
            map.clear_overlays()
        print(f"LOS from {(x1, y1)} to {(x2, y2)}: {los}")
        

if __name__ == "__main__":
    main()
    
