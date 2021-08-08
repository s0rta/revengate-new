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

import time
import heapq
import random
import itertools
from copy import deepcopy
from enum import IntEnum, auto
from collections import defaultdict

from . import geometry as geom
from .randutils import *
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


TEXT_TILE = {TileType.SOLID_ROCK: '▓',
             TileType.FLOOR: '.', 
             TileType.WALL: '░', 
             TileType.WALL_V: '|', 
             TileType.WALL_H: '─', 
             TileType.DOORWAY: '◠'}

WALKABLE = [TileType.FLOOR]
SEE_THROUGH = [TileType.FLOOR, TileType.DOORWAY]
WALLS = [TileType.WALL, TileType.WALL_H, TileType.WALL_V]

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
        self._a_to_pos = {}  # actor to position mapping
        self._pos_to_a = {}  # position to actor mapping
        self._i_to_pos = {}  # item to position
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

    def is_in_map(self, pos):
        """ Return true if the position is inside the map. """
        w, h = self.size()
        x, y = pos
        return 0<=x<w and 0<=y<h

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
    
    def _ring(self, center, radius=1, free=False, shuffle=False, filter_pred=None):
        """ Return a list of coords defining a ring with the given centre.  
        
        The shape is a square for square tiles and a hex for hex tiles, only 
        tiles inside the map are returned. If filter_pred is supplied, only 
        tiles for which filter_pred(t) is True are returned.
        """
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

        if filter_pred:
            tiles = filter(filter_pred, tiles)

        if free:
            tiles = [t for t in tiles if self.is_free(t)]
        
        return tiles        
    
    def adjacents(self, pos, free=False, shuffle=False, filter_pred=None):
        """ Return a list of coordinates for tiles adjacent to pos=(x, y).
        
        Map boundaries are checked. 
        If free=True, only tiles availble for moving are returned. 
        """
        return self._ring(pos, 1, free, shuffle, filter_pred)
    
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
        
    def front_cross(self, from_pos, pivot_pos):
        """ Return the three coords that would move in straight line from 
        pivot_pos without going back to from_pos. Diagonals are not returned.
        """
        x, y = pivot_pos
        return [p for p in [(x-1, y), (x+1, y), (x, y-1), (x, y+1)]
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
    
    def to_text(self, axes=False):
        """ Return a Unicode render of the map suitable for display in a 
        terminal.
        
        axes: added graduated axes around the render
        """
        
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
        for (x, y), char in self.iter_overlays_text():
            cols[x][y] = char

        if axes:
            w, h = self.size()
            mat = [[" " for j in range(h+2)] for i in range(w+2)]
            for i in range(w):
                for j in range(h):
                    mat[i+1][j+1] = cols[i][j]
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
            cols = mat

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
    branching_factor = .10
    
    def __init__(self, map):
        super(Builder, self).__init__()
        self.map = map
        self._rooms = []
        self.mazes = []

    def random_room(self, width, height, nb_retry=4):
        """ Add a random room to the map, return it's bottom-left and top-right 
        corners or False if the room can't be generated.
        
        If width or height are tupples, they are taken to represent the range of 
        acceptable random dimensions, otherwise, they are to be integers 
        representing exact dimensions. 
        
        The new room is tested for intersection with existing rooms. If there 
        is a clash, nb_retry attemps are done.
        """
        def any_intersect(rect):
            for r in self._rooms:
                if r.intersect(rect):
                    return True
            return False

        if isinstance(width, (tuple, list)):
            width = rint(width)
        if isinstance(height, (tuple, list)):
            height= rint(height)
        mw, mh = self.map.size()
        
        for i in range(nb_retry+1):
            x1 = random.randrange(0, mw - width)
            y1 = random.randrange(0, mh - height)
            rect = (x1, y1), (x1+width, y1+height)
            if not any_intersect(rect):
                self.room(*rect, True)
                return rect
        return False
                
    def init(self, width, height, fill=TileType.SOLID_ROCK):
        self.map.tiles = [[fill]*height for i in range(width)]
        
    def is_frozen(self, pos):
        for m in self.mazes:
            if m.is_frozen(pos):
                return True
        return False
        
    def room(self, corner1, corner2, walls=False):
        room = RoomPlan(corner1, corner2, walls)
        self._rooms.append(room)
        room.set_tiles(self.map)

    def touching_mazes(self, pos, ignore):
        """ Return the list of mazes touched by a position. 
        
        ignore: a list of position to ignore
        """
        return [m for m in self.mazes
                if m.touching(pos, ignore)]

    def in_mazes(self, pos):
        """ Return a list of mazes that include pos in a room or a corridor."""
        return [m for m in self.mazes if pos in m]

    def mk_step(self, pos, cur_pos, prev_pos, cur_maze, force_connect=False):
        """ Return a MazeStep for pos or None if the step would be illegal 
        with the current state of maze generation. """
        if pos == prev_pos or not self.map.is_in_map(pos) or self.is_frozen(pos):
            return None

        step = MazeStep(pos)
        step.mazes = self.touching_mazes(pos, [cur_pos, prev_pos])

        # Don't connect back to self until we are fully connected (no 
        # other mazes), then connect back to self according to the 
        # target branching_factor
        if force_connect:
            return step
        elif len(self.mazes) > 1:
            if cur_maze in step.mazes:
                return None
        elif cur_maze in step.mazes:
            if rftest(1 - self.branching_factor):
                return None
        return step
        
    def maze_connect(self, ratio=0.5):
        """ Connect all the rooms with a maze of corridors until `ratio` 
        fraction of the map is covered. """
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
                return biased_choice(steps, 
                                     self.straight_line_bias, 
                                     prefered_step)
            else:
                return None

        w, h = self.map.size()
        tot_area = w * h
        maze_ratio = sum(m.area for m in self.mazes) / tot_area
        print(f"Initial ratio is {maze_ratio}")
        prev = None
        
        # XXX
        debug_overlay = MapOverlay()
        self.map.add_overlay(debug_overlay)
        
        nb_iter = 0
        while maze_ratio < .25 and nb_iter <= 2000: 
            nb_iter += 1
            # TODO: force exit after max-iter (probably 100)
            # TODO: connect new branches when we restart
            if self.mazes:                    
                cur_maze, other_mazes = rpop(self.mazes)
                x, y = cur_maze.rand_wall()
            else:
                break
                # FIXME: start in a hallway instead
            run_start = (x, y)
            self.map.tiles[x][y] = TileType.DOORWAY
            step = next_step((x, y), cur_maze=cur_maze, other_mazes=other_mazes)
            while step:
                prev = (x, y)
                x, y = step.pos
                cur_maze.add(step.pos)
                if len(step.mazes) > 0:  # just made a connection
                    cur_maze = self.merge_mazes(step.mazes + [cur_maze])

                    print(f"now conneted at {step.pos}")
                    # debug_overlay.place("X", step.pos)

                    diags = self.map.front_diags(prev, step.pos)
                    cross = self.map.front_cross(prev, step.pos)
                    if (any(map(self.in_mazes, diags)) 
                         and not any(map(self.in_mazes, cross))):
                        opp = self.map.opposite(prev, step.pos)
                        step = self.mk_step(opp, step.pos, prev, cur_maze, True)
                    else:
                        step = None  # got back to sub-maze selection
                else:
                    step = next_step((x, y), prev, cur_maze, other_mazes)
            maze_ratio = sum(m.area for m in self.mazes) / tot_area
            connected = False
        # TODO: force connect all rooms still unconnect after ratio is reached
        # TODO: fix the doorways into nowhere
        # TODO: debug joints with overlays
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
    def __init__(self, corner1, corner2, walls=False):
        self.bl, self.tr = geom.cannon_corners(corner1, corner2)
        self.has_walls = walls
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

    def to_rect(self): 
        return (self.bl, self.tr)
    
    @property
    def area(self):
        (x1, y1), (x2, y2) = self.to_rect()
        return (x2 - x1) * (y2 - y1)

    def rand_wall(self):
        """ Return a random non-corner wall in of a room. """
        (x1, y1), (x2, y2) = self.to_rect()
        width = x2-x1-2
        height = y2-y1-2
        offset = random.randrange(width*2 + height*2)
        if offset < width:
            return (x1+offset+1, y1)
        elif offset < width*2:
            return (x1+offset-width+1, y2)
        elif offset < width*2 + height:
            return (x1, y1+offset-width*2+1)
        else:
            return (x2, y1+offset-width*2-height+1)

    def set_tiles(self, map):
        """ Set the tiles on the map representing the room. """
        # TODO: handle doors
        (x1, y1), (x2, y2) = self.to_rect()
        if self.has_walls:
            for x in range(x1, x2+1):
                map.tiles[x][y1] = TileType.WALL
                map.tiles[x][y2] = TileType.WALL
            for y in range(y1+1, y2):
                map.tiles[x1][y] = TileType.WALL
                map.tiles[x2][y] = TileType.WALL
            x1, y1, x2, y2 = x1+1, y1+1, x2-1, y2-1

        for x in range(x1, x2+1):
            for y in range(y1, y2+1):
                map.tiles[x][y] = TileType.FLOOR

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
        # TODO: is_connector?
        
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
        x, y = pos
        if self.map.tiles[x][y] in WALLS:
            self.map.tiles[x][y] = TileType.DOORWAY
        else:
            self.map.tiles[x][y] = TileType.FLOOR

        if not pos in self._rooms:
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
        # TODO: target the rooms with fewer doors
        room = random.choice(self._rooms)
        return room.rand_wall()


def main():
    RSTATE = ".randstate.json"
    # rstate_save(RSTATE)
    # rstate_restore(RSTATE)

    map = Map()
    builder = Builder(map)
    builder.init(140, 30)
    # builder.room(5, 5, 35, 15, True)
    for i in range(5):
        builder.random_room((5, 20), (5, 10))
    builder.maze_connect()
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
    
