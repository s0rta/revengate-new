# Copyright © 2020–2022 Yannick Gingras <ygingras@ygingras.net>

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

import time
import heapq
import itertools
from uuid import uuid4
from copy import deepcopy
from enum import IntEnum, auto
from collections import defaultdict

from . import geometry as geom
from . import tender
from .randutils import rng
from .actors import Actor
from .items import Item, ItemCollection
from .utils import Array

# Only Square tiles are implemented, but being able to switch between Square 
# and Hex would be great.  Hex math is well explained here:
# - https://www.redblobgames.com/grids/hexagons/
# - http://www-cs-students.stanford.edu/~amitp/Articles/Hexagon1.html
# Python packages of interest are:
# - Hexy: coordinate transforms, good for tap events
# - hexutil: Hex.distance and A* implementation

class ScopeType(IntEnum):
    VISIBLE = auto()

class MapScope:
    def __init__(self, map, scope_type, at, radius=None, pred=None, include_at=False):
        """ at: a coord tupple or an actor
        pred: a callable that receives a coord tupple OR a class that is used to test 
              things at the coord
        """
        self.map = map
        self.scope_type = scope_type
        if isinstance(at, Actor):
            at = self.map.find(at)
        self.at = at
        self.radius = radius
        self.pred = pred
        self.include_at = include_at

    def _disc(self, at, max_radius):
        for radius in range(1, max_radius+1):
            tiles = self.map._ring(at, radius, free=False, shuffle=False)
            for t in tiles:
                yield t

    def _run_query(self):
        if self.include_at:
            all_coords = []
        else:
            all_coords = [self.at]
        if self.scope_type == ScopeType.VISIBLE:
            all_coords += [coord for coord in self._disc(self.at, self.radius) 
                           if self.map.line_of_sight(self.at, coord)]
        if self.pred:
            return iter(self._filter_with_pred(all_coords))
        else:
            return iter(all_coords)

    def _filter_with_pred(self, coords):
        if self.pred == Actor:  # TODO: check for sub classes
            return [coord for coord in coords 
                    if isinstance(self.map.actor_at(coord), self.pred)]
        elif self.pred == Item:
            return [coord for coord in coords 
                    if isinstance(self.map.item_at(coord), self.pred)]
        elif callable(self.pred):
            return [coord for coord in coords if self.pred(coord)]
             
    def __iter__(self):
        return self.iter_coords()

    @property
    def coords(self):
        list(self.iter_coords)
        
    def iter_coords(self):
        return self._run_query()

    @property
    def actors(self):
        return list(self.iter_actors())

    def iter_actors(self):
        for coord in self:
            actor = self.map.actor_at(coord)
            if actor is not None:
                yield coord, actor

    @property
    def items(self):
        return list(self.iter_items())

    def iter_items(self):
        for coord in self:
            stack = self.map.items_at(coord)
            if stack:
                for item in stack:
                    yield coord, item

    @property
    def tiles(self):
        return list(self.iter_tiles())

    def iter_tiles(self):
        for coord in self:
            yield coord, self.map[coord]

    

class TileType(IntEnum):
    SOLID_ROCK = auto()
    FLOOR = auto()
    WALL = auto()
    WALL_V = auto()
    WALL_H = auto()
    DOORWAY_OPEN = auto()
    DOORWAY_CLOSED = auto()


TEXT_TILE = {TileType.SOLID_ROCK: '▓',
             TileType.FLOOR: '.', 
             TileType.WALL: '░', 
             TileType.WALL_V: '|', 
             TileType.WALL_H: '─', 
             TileType.DOORWAY_OPEN: '╦', 
             TileType.DOORWAY_CLOSED: '╥'}

WALKABLE = [TileType.FLOOR, TileType.DOORWAY_OPEN]
SEE_THROUGH = [TileType.FLOOR, TileType.DOORWAY_OPEN]
WALLS = [TileType.WALL, TileType.WALL_H, TileType.WALL_V]
         

class Connector:
    """ A tile that connects to another map or another area. """

    def __init__(self, char=">", dest_map=None):
        self.char = char
        self.dest_map = dest_map


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
        super().__init__()
        self.id = str(uuid4())
        self.name = name
        self.tiles = None
        self.overlays = []
        self._a_to_pos = {}  # actor to position mapping
        self._pos_to_a = {}  # position to actor mapping
        self._i_to_pos = {}  # item to position
        self._pos_to_i = defaultdict(ItemCollection)  # position to items
        
        # connections to neighbouring maps ({mapid:pos}), our side of the connection
        self._map_to_conn = {}  

    def connect(self, pos1, there, pos2):
        """ Connect pos1 on this map to pos2 on there (another map). """
        if not isinstance(there, Map):
            raise TypeError(f"Only maps are supported, not {type(there)}")
        for tile in [self[pos1], there[pos2]]:
            if not isinstance(tile, Connector):
                raise TypeError("Connecting maps must be done at Connector tiles.")
        self._map_to_conn[there.id] = pos1
        self[pos1].dest_map = there.id

        # return path
        there._map_to_conn[self.id] = pos2
        there[pos2].dest_map = self.id

    def arrival_pos(self, mapid):
        """ Return where to place the hero if they just arrived from mapid """
        return self._map_to_conn[mapid]

    def __getstate__(self):
        """ Return a representation of the internal state that is suitable for the 
        pickling protocol. """
        state = self.__dict__.copy()
        if tender.hero in self._a_to_pos:
            # the hero must be serialized by whoever is in charge or saving the tender
            state["_a_to_pos"] = self._a_to_pos.copy()
            pos = state["_a_to_pos"].pop(tender.hero)
            state["_pos_to_a"] = self._pos_to_a.copy()
            del state["_pos_to_a"][pos]
            state["__hero_pos"] = pos
        return state

    def __setstate__(self, state):
        """ Restore an instance from a pickled state.
        
        tender.hero must be restored before any map on which the hero is present. """
        if "__hero_pos" in state:
            if tender.hero is None:
                raise RuntimeError("tender.hero must be restored before any map that "
                                   "contains the hero.")
            hero_pos = state.pop("__hero_pos")
        else:
            hero_pos = None

        if "tiles" in state and not isinstance(state["tiles"], Array):
            state["tiles"] = Array.from_list(state["tiles"])

        self.__dict__.update(state)
        
        if hero_pos:
            self.place(tender.hero, hero_pos)

    def __getitem__(self, pos):
        x, y = pos
        return self.tiles[x][y]

    def __setitem__(self, pos, tile):
        x, y = pos
        self.tiles[x][y] = tile

    def size(self):
        """ Return a (width, height) tuple. """
        if self.tiles:
            return self.tiles.size()
        else:
            return (0, 0)

    def is_in_map(self, pos):
        """ Return true if the position is inside the map. """
        w, h = self.size()
        x, y = pos
        return 0<=x<w and 0<=y<h

    def iter_coords(self):
        """ Return an iterator for all the (x, y) coordinates in the map.
        
        No order guaratees. 
        """
        w, h = self.size()
        for x in range(w):
            for y in range(h):
                yield (x, y)

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
        """ Return an iterator for ((x, y), object) pairs.  
        Positions can be seen more than once. 
        The stacking order of overlays is preserved. """
        return itertools.chain(*[o.items() for o in self.overlays])

    def iter_overlays_text(self):
        """ Like Map.iter_overlays() but for text representation of things. """
        return itertools.chain(*[o.text_items() for o in self.overlays])
    
    def visible_scope(self, at, radius, pred=None, include_at=False):
        return MapScope(self, ScopeType.VISIBLE, at, radius, pred, include_at)

    def add_overlay(self, overlay):
        self.overlays.append(overlay)
    
    def remove_overlay(self, overlay):
        self.overlays = [o for o in self.overlays if o != overlay]
    
    def clear_overlays(self):
        self.overlays = []
    
    def items_at(self, pos):
        if pos in self._pos_to_i:
            return self._pos_to_i[pos]
        else:
            return None
    
    def char_at(self, pos):
        """ Return the character representation of what is at pos. """
        if pos in self._pos_to_a:
            return self._pos_to_a[pos].char
        if pos in self._pos_to_i and self._pos_to_i[pos]:
            return self._pos_to_i[pos].char
        
        tile = self[pos]
        if isinstance(tile, Connector):
            return tile.char
        return TEXT_TILE[tile]
    
    def actor_at(self, pos):
        return self._pos_to_a.get(pos)
        
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
    
    def _ring(self, center, radius=1, free=False, shuffle=False, 
              filter_pred=None, in_map=True, sparse=True):
        """ Return a list of coords defining a ring with the given centre.  
        
        The shape is a square. 
        If in_map=True, only tiles inside the map are returned. 
        If filter_pred is supplied, only tiles for which filter_pred(t) is True 
        are returned.
        If sparse=True: invalid tiles are not returns, returned as None otherwise.
        Tiles are returned counter-clockwise starting at the bottom-left corner 
        of the ring unless shuffle=True.
        """
        def sift(pred, tiles):
            if sparse:
                tiles = filter(pred, tiles)
            else:
                tiles = [pred(t) and t or None for t in tiles]
            return list(tiles)

        x, y = center
        w, h = self.size()
        
        tiles = []
        r = radius
        for i in range(-r, r+1):
            tiles.append((x+i, y-r))
        for j in range(-r+1, r+1):
            tiles.append((x+r, y+j))
        for i in range(r-1, -r-1, -1):
            tiles.append((x+i, y+r))
        for j in range(r-1, -r, -1):
            tiles.append((x-r, y+j))
    
        if in_map:
            tiles = sift(self.is_in_map, tiles)
        if shuffle:
            rng.shuffle(tiles)

        if filter_pred:
            tiles = sift(filter_pred, tiles)

        if free:
            tiles = sift(self.is_free, tiles)

        return list(tiles)
        
    def adjacents(self, pos, free=False, shuffle=False, filter_pred=None, 
                  in_map=True, sparse=True):
        """ Return a list of coordinates for tiles adjacent to pos=(x, y).
        
        Map boundaries are checked. 
        If free=True, only tiles availble for moving are returned. 
        """
        return self._ring(pos, 1, free, shuffle, filter_pred, in_map, sparse)
    
    def opposite(self, from_pos, pivot_pos):
        """ Return a coordinate that is opposite to from_pos relative to 
        pivot_pos or None if the opposite would fall outside the map. """
        (x1, y1), (x2, y2) = from_pos, pivot_pos
        dx, dy = x2-x1, y2-y1
        x3, y3 = x2+dx, y2+dy
        w, h = self.size()
        if 0 <= x3 < w and 0 <= y3 < h:
            return (x3, y3)
        else:
            return None
        
    def cross(self, pos):
        """ Return the 4 straight line coords touching pos. """
        x, y = pos
        return [(x-1, y), (x+1, y), (x, y-1), (x, y+1)]
        
    def front_cross(self, from_pos, pivot_pos):
        """ Return the three coords that would move in straight line from 
        pivot_pos without going back to from_pos. Diagonals are not returned.
        """
        return [p for p in self.cross(pivot_pos)
                if p != from_pos]

    def front_diags(self, from_pos, pivot_pos):
        """ Return the two diagonal tiles from pivot_pos moving away from 
        from_pos."""
        x1, y1 = from_pos
        x2, y2 = pivot_pos
        if x1 == x2:
            delta = y2 - y1
            return [(x2-1, y2+delta), (x2+1, y2+delta)]
        elif y1 == y2:
            delta = x2 - x1
            return [(x2+delta, y2-1), (x2+delta, y2+1)]
        else:
            raise ValueError(f"{from_pos} and {pivot_pos} do not seem "
                             "to be in line.")

    def back_diags(self, from_pos, pivot_pos):
        x1, y1 = from_pos
        x2, y2 = pivot_pos
        if x1 == x2:
            delta = y2 - y1
            return [(x2-1, y2-delta), (x2+1, y2-delta)]
        elif y1 == y2:
            delta = x2 - x1
            return [(x2-delta, y2-1), (x2-delta, y2+1)]
        else:
            raise ValueError(f"{from_pos} and {pivot_pos} do not seem "
                             "to be in line.")

    def connectedness(self, pos):
        """ Return the maximum connection number for a position. 
        
        The maximum connection number is how many sides and diagonals in a row 
        a already connected. """

        def is_unconn(pos):
            x, y = pos
            # FIXME: more than one tile type is unconn
            return self.tiles[x][y] in (TileType.SOLID_ROCK, )
            
        adjs = self.adjacents(pos, free=False, in_map=True, sparse=False)

        # The current implementation only works if we start on a diagonal. The 
        # number would be the same, but our assumptions on what is considered 
        # too high would not hold. See 2021-11-13 notes.
        for adj in adjs[::2]:
            if adj is None:
                continue
            if geom.is_diag(pos, adj):  # all is good!
                break
            else:
                msg = f"Adjacents for {pos} do not start on a diagonal."
                raise ValueError(msg)

        max_conn = 0
        cur_conn = 0
        size = len(adjs)
        for i in range(size * 2 - 1):
            tile = adjs[i % size]
            if tile is None or is_unconn(tile):
                if cur_conn > max_conn:
                    max_conn = cur_conn
                cur_conn = 0
                if i >= (size-1):
                    break
            else:
                cur_conn += 1
        return max_conn

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

    def random_pos(self, free):
        """ Return the (x, y) coordinate of a random tile inside the map.
        
        If free=True, the tile can allow an actor to step on.
        Raise a RuntimeError if no suitable tile can be found. """
        # Fully random attempts a few times, then we systematically explore all
        # the tile if we still haven't found one
        w, h = self.size()
        for i in range(5):
            x, y = rng.randrange(w), rng.randrange(h)
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

    def is_walkable(self, pos):
        w, h = self.size()
        x, y = pos
        if not (0 <= x < w and 0 <= y < h):
            return False
        tile = self[pos]
        return isinstance(tile, Connector) or tile in WALKABLE

    def is_doorway(self, pos):
        tile = self[pos]
        return tile in [TileType.DOORWAY_OPEN, TileType.DOORWAY_CLOSED]

    def is_free(self, pos):
        """ Is the tile at pos=(x, y) free for a nactor to step on?"""
        if self.is_walkable(pos) and pos not in self._pos_to_a:
            return True
        else:
            return False
        
    def _rebuild_path(self, start, stop, seen_map):
        path = [stop]
        current = stop
        while current != start:
            current = seen_map[current]
            path.append(current)
        return list(reversed(path))

    def path(self, start, goal):
        """ Find an optimal path going from (x1, y1) to (x2, y2) taking 
        obstacles into account. 
        
        Return the path as a list of (x, y) tuples. """
        # Using the A* algorithm
        came_from = {} # a back track map from one point to its predecessor
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

    def __contains__(self, thing):
        return thing in self._a_to_pos or thing in self._i_to_pos

    def place(self, thing, pos=None, fallback=False):
        """ Put thing on the map at pos=(x, y). 
        If pos is not not supplied, a random position is selected. 
        If fallback=True, a nearby space is selected when pos is not available.
        """
        if thing in self:
            raise ValueError(f"{thing} is already on the map, use Map.move()" 
                             " to change it's position.")
        if pos is None:
            pos = self.random_pos(free=True)
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
            pos = self._i_to_pos[thing]
            self._pos_to_i[pos].remove(thing)
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
    
    def to_text(self, axes=False):
        """ Return a Unicode render of the map suitable for display in a 
        terminal.
        
        axes: add graduated axes on the margins of the render
        """
        
        # Convert to text
        #  not using iter_tiles() because we let actors and items take precedence
        w, h = self.size()
        chars = Array(w, h, None)
        for x, y in self.iter_coords():
            chars[x][y] = self.char_at((x, y))
            
        # overlay extra layers
        for (x, y), char in self.iter_overlays_text():
            chars[x][y] = char

        if axes:
            mat = Array(w+2, h+2, " ")

            for i in range(w):
                for j in range(h):
                    mat[i+1][j+1] = chars[i][j]
                if i % 5 == 0 and i % 10:
                    mat[i+1][0] = '|'
                    mat[i+1][-1] = '|'
                if i % 10 == 0:
                    c = f"{i//10 % 10}"
                    mat[i+1][0] = c
                    mat[i+1][-1] = c
            for j in range(h):
                if j % 5 == 0 and i % 10:
                    mat[0][j+1] = '–'
                    mat[-1][j+1] = '–'
                if j % 10 == 0:
                    c = f"{j//10 % 10}"
                    mat[0][j+1] = c
                    mat[-1][j+1] = c
            chars = mat

        # stringify
        lines = []
        for row in chars.iter_rows():
            lines.append("".join(row))
        # move the origin to bottom left
        return "\n".join(reversed(lines))


class MapOverlay:
    """ A sparse overlay to be rendered on top of a map. """
    def __init__(self):
        super(MapOverlay, self).__init__()
        self.tiles = defaultdict(lambda: {}) # keep the same addressing at Map

    def _as_char(self, obj):
        # We do not take a single char prefix since some Emojis have multi-char 
        # composition sequences (ex: bald man is "👨‍🦲"), which we want to support.
        if obj in TEXT_TILE:
            return TEXT_TILE[obj]
        elif isinstance(obj, str):
            return obj
        else:
            return str(obj)
        
    def char_at(self, pos):
        # FIXME: handle object, actors, and portals
        x, y = pos
        if x in self.tiles:
            if y in self.tiles[x]:
                return self._as_char(self.tiles[x][y])
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
        for x in self.tiles:
            for y in self.tiles[x]:
                yield ((x, y), self._as_char(self.tiles[x][y]))


class Builder:
    """ Builder for map features. """
    straight_line_bias = 3.0
    branching_factor = .5
    doors_range = (1, 5)
    
    def __init__(self, map):
        super().__init__()
        self.map = map
        self._rooms = []
        self.mazes = []

    def random_room(self, width, height, nb_retry=4):
        """ Add a random room to the map, return it's bottom-left and top-right 
        corners or False if the room can't be generated.
        
        If width or height are tuples, they are taken to represent the range of 
        acceptable random dimensions, otherwise, they are to be integers 
        representing exact dimensions. 
        
        The new room is tested for intersection with existing rooms. If there 
        is a clash, nb_retry attempts are done.
        """
        def any_intersect(rect):
            for r in self._rooms:
                if r.intersect(rect):
                    return True
            return False

        if isinstance(width, (tuple, list)):
            width = rng.rint(width)
        if isinstance(height, (tuple, list)):
            height = rng.rint(height)
        mw, mh = self.map.size()
        
        for i in range(nb_retry+1):
            x1 = rng.randrange(0, mw - width)
            y1 = rng.randrange(0, mh - height)
            rect = (x1, y1), (x1+width, y1+height)
            if not any_intersect(rect):
                self.room(*rect, walls=True)
                return rect
        return False
                
    def init(self, width, height, fill=TileType.SOLID_ROCK):
        self.map.tiles = Array(width, height, fill)
        
    def is_frozen(self, pos):
        for m in self.mazes:
            if m.is_frozen(pos):
                return True
        return False
        
    def room(self, corner1, corner2, doors_target=None, walls=False):
        if doors_target is None:
            doors_target = rng.rint(self.doors_range)
        room = RoomPlan(self.map, corner1, corner2, doors_target, walls)
        self._rooms.append(room)
        room.set_tiles()

    def staircase(self, pos=None, char=">", dest_pos=None, dest_map=None):
        """ Add a staircase. 
        
        If pos=None, a random location is selected. 
        If dest_map=None, it's left pending to be determined later.
        
        Return where the staircase was placed. 
        """
        if pos is None:
            if not self._rooms:
                raise RuntimeError("Staircases can only be placed after rooms "
                                   "have been created.")
            room = rng.choice(self._rooms)
            pos = rng.pos_in_rect(room.to_rect(inside_walls=True))
        self.map[pos] = Connector(char)
        if dest_map is not None:
            self.map.connect(pos, dest_map, dest_pos)
        return pos

    def touching_mazes(self, pos, ignore):
        """ Return the list of mazes touched by a position. 
        
        ignore: a list of position to ignore
        """
        return [m for m in self.mazes
                if m.touching(pos, ignore)]

    def in_mazes(self, pos):
        """ Return a list of mazes that include pos in a room or a corridor."""
        return [m for m in self.mazes if pos in m]

    def free_front_cross(self, from_pos, pivot_pos):
        """ Return true of the front cross of a position is free. """
        for pos in self.map.front_cross(from_pos, pivot_pos):
            x, y = pos
            if not (not self.in_mazes(pos) or self.map.tiles[x][y] in WALLS):
                return False
        return True                

    def mk_step(self, pos, cur_pos, prev_pos, cur_maze, force_connect=False):
        """ Return a MazeStep for pos or None if the step would be illegal 
        with the current state of maze generation. """
        if pos == prev_pos or not self.map.is_in_map(pos) or self.is_frozen(pos):
            return None

        ignore = [cur_pos, prev_pos]
        if len(self.mazes) == 1:
            ignore += self.map.back_diags(cur_pos, pos)
        step = MazeStep(pos)
        step.mazes = self.touching_mazes(pos, ignore)

        # Don't connect back to self until we are fully connected (no 
        # other mazes), then connect back to self according to the 
        # target branching_factor
        if force_connect:
            return step
        elif len(self.mazes) > 1:
            if cur_maze in step.mazes:
                return None
        elif cur_maze in step.mazes:
            if rng.rftest(1 - self.branching_factor):
                return None
        return step
        
    def valid_run_start(self, pos, cur_maze):
        """ Return True if pos is a good place to start growing the maze. """
        cross = self.map.cross(pos)
        for pos in cross:
            if self.map.is_in_map(pos) and self.map.is_doorway(pos):
                return False
        return True
        
    def maze_connect(self, ratio=0.5, debug=False):
        """ Connect all the rooms with a maze of corridors until `ratio` 
        fraction of the map is covered. 
        
        debug: add debugging annotations to the generated map and log generation metrics
        """
        w, h = self.map.size()
        
        self.mazes = [MazePlan(self.map, [room]) for room in self._rooms]

        def next_step(pos, prev=None, cur_maze=None, other_mazes=None):
            """ Return the next step to take. """
            steps = [self.mk_step(p, pos, prev, cur_maze) 
                     for p in self.map.front_cross(prev, pos)]
            steps = [s for s in steps if s]
            
            if steps:
                if prev:
                    prefered_step = self.map.opposite(prev, pos)
                else:
                    prefered_step = None
                return rng.biased_choice(steps, 
                                         self.straight_line_bias, 
                                         prefered_step)
            else:
                return None

        w, h = self.map.size()
        tot_area = w * h
        maze_ratio = sum(m.area for m in self.mazes) / tot_area
        if debug:
            print(f"Initial ratio is {maze_ratio}")
        prev = None
        
        if debug:
            debug_overlay = MapOverlay()
            self.map.add_overlay(debug_overlay)
        
        nb_iter = 0
        while maze_ratio < .25 and nb_iter <= 2000: 
            nb_iter += 1
            # TODO: force exit after max-iter (probably 100)
            # TODO: connect new branches when we restart
            if self.mazes:                    
                cur_maze, other_mazes = rng.rpop(self.mazes)
                x, y = cur_maze.rand_cor_start()
            else:
                break
                # FIXME: start in a hallway instead
            run_start = (x, y)
            run_lenght = 0
            if self.valid_run_start(run_start, cur_maze):
                cur_maze.add(run_start)
                if debug:
                    debug_overlay.place('x', run_start)
                step = next_step((x, y), cur_maze=cur_maze, other_mazes=other_mazes)
            else:
                step = None  # abandon the run
            while step:
                run_lenght += 1
                prev = (x, y)
                x, y = step.pos

                if len(step.mazes) > 0:  # just made a connection
                    cur_maze = self.merge_mazes(step.mazes + [cur_maze])
                cur_maze.add(step.pos)

                if debug:
                    debug_overlay.place(str(run_lenght % 10), step.pos)

                if len(step.mazes) > 0:  # finalize the connection
                    conn = self.map.connectedness(step.pos)
                    if debug:
                        print(f"now conneted at {step.pos}, ({len(self.mazes)} mazes) "
                              f"connectedness: {conn}")
                        
                    diags = self.map.front_diags(prev, step.pos)
                    if (any(map(self.in_mazes, diags)) 
                         and self.free_front_cross(prev, step.pos)):
                        opp = self.map.opposite(prev, step.pos)
                        step = self.mk_step(opp, step.pos, prev, cur_maze, True)
                    else:
                        # FIXME: this is only good if the make is not fully connected
                        step = None  # go back to sub-maze selection
                else:
                    step = next_step((x, y), prev, cur_maze, other_mazes)
            maze_ratio = sum(m.area for m in self.mazes) / tot_area
            connected = False
        # TODO: force connect all rooms still unconnect after ratio is reached
        # TODO: fix the doorways into nowhere
        # TODO: debug joints with overlays
        if debug:
            print(f"Final ratio is {maze_ratio:0.3} after {nb_iter} iterations" 
                  f" ({len(self.mazes)} mazes)")

    def merge_mazes(self, mazes):
        """ Merge all the MazePlans in mazes and update self.mazes. 
        
        Return the merged MazePlan.
        """
        mazes = set(mazes) # dedups before merging
        self.mazes = [m for m in self.mazes if m not in mazes] 

        merged = mazes.pop()
        for m in mazes:
            merged = merged.union(m)
        self.mazes.append(merged)

        return merged


# TODO: move this to a utils module or something more general than here
def partition(seq, predicate):
    """ Partition a sequence into sub-sequences according the value returned 
    by the boolean predicate function. The True partition is returned first. 
    """
    groups = {True: [], False: []}
    for item in seq:
        groups[bool(predicate(item))].append(item)
    return [g for k,g in sorted(groups.items(), reverse=True)]


class RoomPlan:
    """ A builder helper to manage a soon-to-be room on a map. """
    def __init__(self, map, corner1, corner2, doors_target, walls=False):
        self.map = map
        self.bl, self.tr = geom.cannon_corners(corner1, corner2)
        self.has_walls = walls
        self.doors_target = doors_target
        self.doors = []

    def __contains__(self, point):
        x, y = point
        x1, y1 = self.bl
        x2, y2 = self.tr
        return x1 <= x <= x2 and y1 <= y <= y2

    def __eq__(self, other):
        rect = self.to_rect()
        if isinstance(other, RoomPlan):
            return other.to_rect == rect
        elif isinstance(other, tuple):
            return other == rect
        else:
            raise NotImplemtedError(f"Don't know how to compare {type(other)}"
                                    " to RoomPlan")

    def to_rect(self, inside_walls=False):
        if inside_walls and self.has_walls:
            x1, y1 = self.bl
            x2, y2 = self.tr
            return ((x1+1, y1+1), (x2-1, y2-1))
        else:
            return (self.bl, self.tr)
    
    @property
    def area(self):
        (x1, y1), (x2, y2) = self.to_rect()
        return (x2 - x1) * (y2 - y1)

    def select_weight(self):
        """ Return how important it should be to select this room. """
        return self.doors_target - len(self.doors)

    def add_door(self, pos):
        self.doors.append(pos)
        self.map[pos] = TileType.DOORWAY_OPEN

    def rand_wall(self):
        """ Return a random non-corner wall in of a room. """
        (x1, y1), (x2, y2) = self.to_rect()
        width = x2-x1-2
        height = y2-y1-2
        offset = rng.randrange(width*2 + height*2)
        if offset < width:
            return (x1+offset+1, y1)
        elif offset < width*2:
            return (x1+offset-width+1, y2)
        elif offset < width*2 + height:
            return (x1, y1+offset-width*2+1)
        else:
            return (x2, y1+offset-width*2-height+1)

    def set_tiles(self):
        """ Set the tiles on the map representing the room. """
        # TODO: handle doors
        (x1, y1), (x2, y2) = self.to_rect()
        if self.has_walls:
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

    def intersect(self, room):
        """ Return True if room overlaps with self. """
        if isinstance(room, RoomPlan):
            other_rect = room.to_rect()
        else:
            other_rect = room
        return geom.rect_interstect(self.to_rect(), other_rect)

    def iter_tiles(self):
        if self.has_walls:
            (x1, y1) = self.bl
            (x2, y2) = self.tr
            return geom.iter_tiles(((x1+1, y1+1), (x2-1, y2-1)))
        else:
            return geom.iter_tiles(self.to_rect())


class MazeStep:
    """ A step in the maze creation. 
    
    This is basically a cache so we don't have to recompute expensive 
    operation after we decided which direction to take. 
    """
    
    def __init__(self, pos, mazes=None):
        self.pos = pos
        self.mazes = mazes or []
        self.is_self_connect = False
        self.is_cross_connect = False
        
    def __eq__(self, other):
        if isinstance(other, MazeStep):
            return self.pos == other.pos
        elif isinstance(other, tuple):
            return self.pos == other
        elif other == None:
            return False
        else:
            msg = f"Don't know how to compare MazePlan and {type(other)}"
            raise NotImplementedError(msg)


class MazePlan:
    """ A twisty set of corridors and rooms inside a map. There can be more than one. 
    They must all converge and merge before the map is considered playable. 
    """

    def __init__(self, map, rooms=None, corridors=None):
        self.map = map
        # frozen tiles are final and can't become hallways
        self._frozen_tiles = set()  
        self._corridors = corridors and set(corridors) or set()
        
        walls, no_walls = partition(rooms or [], lambda x:x.has_walls)
        self._walled_rooms = geom.PolyCont(*walls)
        self._no_wall_rooms = geom.PolyCont(*no_walls)
        self._freeze_room_corners()
        
    @property
    def _rooms(self):
        return self._walled_rooms + self._no_wall_rooms

    @property
    def area(self):
        return len(self._corridors) + sum(r.area for r in self._rooms)
    
    def add(self, pos):
        room = None
        for r in self._walled_rooms:
            if pos in r:
                room = r
                break
        x, y = pos
        if room:
            if self.map.tiles[x][y] in WALLS:
                room.add_door(pos)
        elif pos in self._no_wall_rooms:
            pass # nothing to do
        else:
            self.map.tiles[x][y] = TileType.FLOOR
            self._corridors.add(pos)

    def _freeze_room_corners(self):
        """ Mark all the room corners as frozen. """
        for r in self._rooms:
            (x1, y1), (x2, y2) = r.to_rect()
            for pos in [(x1, y1), (x2, y1), (x1, y2), (x2, y2)]:
                self._frozen_tiles.add(pos)
            
    def __contains__(self, pos):
        if isinstance(pos, tuple):
            if pos in self._rooms:
                return True
            else:
                return pos in self._corridors
        else:
            raise ValueError("Can only handle (x, y) coordinates.")

    def bounding_rect(self):
        corridors = sorted(self._corridors)
        cx1, cx2 = corridors[0][0], corridors[-1][0]
        corridors = y_sorted(corridors)
        cy1, cy2 = corridors[0][1], corridors[-1][1]
        
        bls, trs = map(sorted, zip(*self._rooms))
        rx1, rx2 = bls[0][0], trs[-1][0]
        bls = y_sorted(bls)
        trs = y_sorted(trs)
        ry1 = bls[0][1]
        ry2 = bls[-1][1]
        return (min(cx1, rx1), min(cy1, ry1)), (max(cx2, rx2), max(cy2, ry2))
        
    def touching(self, pos, ignore=None):
        """ Return True if pos is in the maze or on a wall along side the maze.
        
        ignore: a collection of postions not to consider. Typically, that would 
        include the step where we are coming from while building the maze.
        """
        if pos in self._walled_rooms:
            return True
        for t in self.map.adjacents(pos):
            if ignore and t in ignore:
                continue
            if t in self._no_wall_rooms:
                return True
            if t in self._corridors:
                return True
        return False
    
    def is_frozen(self, pos):
        return pos in self._frozen_tiles
        
    def union(self, other):
        if isinstance(other, MazePlan):
            return MazePlan(self.map, 
                            self._rooms + other._rooms, 
                            self._corridors.union(other._corridors))
        else:
            raise ValueError("Union is only supported with another MazePlan.")
        
    def rand_wall(self):
        rooms = self._rooms
        weights = [r.select_weight() for r in rooms]
        if sum(weights) > 1:
            room = rng.choices(rooms, weights=weights)[0]
        else:
            room = rng.choice(rooms)
        return room.rand_wall()

    def rand_cor_start(self):
        """ Random starting point for a corridor. """
        # see if all the rooms have all their WALLS
        # pick a rand wall if that's not the case
        # pick a random corridor otherwise
        rooms = self._rooms
        weights = [r.select_weight() for r in rooms]
        if sum(weights) > 1:
            room = rng.choices(rooms, weights=weights)[0]
            return room.rand_wall()
        elif self._corridors:
            return rng.choice(list(self._corridors))
        else:
            room = rng.choice(rooms)
            return room.rand_wall()
        
    def select_weight(self):
        """ Return how important it should be to select this MazePlan. """
        return sum([r.select_weight() for r in self._rooms])


def main():
    RSTATE = ".randstate.json"
    # rng.state_save(RSTATE)
    # rng.state_restore(RSTATE)

    map = Map()
    builder = Builder(map)
    builder.init(140, 30)
    # builder.room(5, 5, 35, 15, True)
    for i in range(5):
        builder.random_room((5, 20), (5, 10))
    builder.maze_connect(debug=True)
    print(map.to_text(True))
    
    #intersect = builder._interstect(*builder._rooms)
    #print(f"Intersect: {intersect}")
    
    # for i in range(20):

    #for i in range(10):
        #x1, y1 = random.randrange(5, 35), random.randrange(5, 15)
        #x2, y2 = random.randrange(5, 35), random.randrange(5, 15)
        #los = map.line_of_sight((x1, y1), (x2, y2))
        #if los:
            #overlay = MapOverlay()
            #for c in los[1:-1]:
                #overlay.place('x', c)
            #overlay.place('@', (x1, y1))
            #overlay.place('d', (x2, y2))
            #map.add_overlay(overlay)
            #print(map.to_text())
            #map.clear_overlays()
        #print(f"LOS from {(x1, y1)} to {(x2, y2)}: {los}")
        

if __name__ == "__main__":
    main()
    
