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

""" 2D graphics rendering and graphical UI elements. """

import os
from pprint import pprint

import kivy
from kivy.app import App
from kivy.core.window import Window
from kivy.core.text import Label as CoreLabel
from kivy.graphics.texture import Texture
from kivy.uix.widget import Widget
from kivy.uix.label import Label
from kivy.uix.button import Button
from kivy.uix.image import Image
from kivy.properties import NumericProperty
from kivy.uix.floatlayout import FloatLayout
from kivy.uix.scatter import Scatter
from kivy.graphics import Color, Rectangle
from kivy.uix.behaviors.focus import FocusBehavior
from kivy import resources
from kivy.animation import Animation

from .maps import TileType, Map, Builder, Connector
from .loader import DATA_DIR, data_file, TopLevelLoader
from .events import is_action
from .utils import Array
from . import tender

# TileType -> path
TILE_IMG = {TileType.SOLID_ROCK: "dungeon/floor/lair_1_new.png", 
            TileType.FLOOR: "dungeon/floor/rect_gray_1_old.png", 
            TileType.WALL: "dungeon/wall/brick_brown_0.png", 
            TileType.DOORWAY_OPEN: "dungeon/open_door.png"}

# tile.char -> path
CONNECTOR_IMG = {"<": "dungeon/gateways/stone_stairs_up.png", 
                 ">": "dungeon/gateways/stone_stairs_down.png"}
EMPTY_IMG = "dungeon/black.png"
TILE_SIZE = 32


class ImgSourceCache:
    def __init__(self):
        resources.resource_add_path(os.path.join(DATA_DIR, "images"))
        self._cache = {}            

    def texture_key(self, thing):
        if isinstance(thing, Connector):
            return (Connector, thing.char)
        elif thing is None or thing in TileType:
            return thing
        else: 
            raise TypeError(f"Unsupported type for texture conversion {type(thing)}")

    def img_source(self, thing):
        key = self.texture_key(thing)
        if key not in self._cache:
            self.load_image(thing)
        return self._cache[key]
        
    def load_image(self, thing):
        key = self.texture_key(thing)
        if isinstance(thing, Connector):
            path = CONNECTOR_IMG[thing.char]
        elif thing is None:
            path = EMPTY_IMG
        elif thing in TILE_IMG:
            path = TILE_IMG[thing]
        else:
            raise TypeError(f"Unsupported type for texture conversion {type(thing)}")
        fq_path = resources.resource_find(path)
        self._cache[key] = fq_path
        return fq_path
            

def best_font(text):
    """ Return a font that looks for the given text.
    
    The main criterion is emoji vs normal text. Pure emoji fonts don't look good for 
    normal text and Kivy does not automatically fall back to alternative fonts if 
    it can't find the requested glyph.

    """
    # other non-emoji: Nimbus Roman Sans, Sans Bold, Tex Gyre Bonum
    # other emoji: Noko Color Emoji, Emoji One
    if text.isascii():
        return "kalimati.ttf"
    else:
        return "Symbola_hint.ttf"


class MapElement(Label):
    def __init__(self, *args, **kwargs):
        text = kwargs.pop("text")
        size = (TILE_SIZE, TILE_SIZE)
        super().__init__(*args, text=text, 
                         font_size="28sp", size=size, bold=True, 
                         font_name=best_font(text), 
                         **kwargs)
        

class MapWidget(FocusBehavior, Scatter):
    """ A widget to display a dungeon with graphical tiles. 
    
    Two coordinate systems are used:
    - map: tile id (map.tiles[x][y]), convention is (mx, my)
    - canvas: pixel position on the canvas, convition is (cy, cy)
    Both systems have (0, 0) at the bottom-left corner.
    """
    
    engine_turn = NumericProperty(defaultvalue=None)  # turn currently being played
    hero_turn = NumericProperty(defaultvalue=None)  # last turn the hero did an action
    
    def __init__(self, *args, map=None, **kwargs):
        if map is not None:
            w, h = map.size()
            size = (w*TILE_SIZE, h*TILE_SIZE)
            kwargs["size"] = size
        super().__init__(*args, **kwargs)
        self.map = map
        self.is_focusable = True
        # pre-load all the textures
        self.cache = ImgSourceCache()
        self._elems = {}  # thing -> MapElement with thing being Actor or ItemCollection
        self.rects = []
        if map is not None:
            self.init_rects()
            self.refresh_map()
            
    def _clear_elem(self, thing):
        elem = self._elems.pop(thing)
        elem.opacity = 0
        self.remove_widget(elem)
        
    def _clear_elems(self):
        for thing in list(self._elems.keys()):
            self._clear_elem(thing)
        
    def set_map(self, map):
        self._clear_elems()
        w, h = map.size()
        self.size = (w*TILE_SIZE, h*TILE_SIZE)
        self.map = map
        self.init_rects()
        self.refresh_map()
        
    def _update_elem(self, mpos, thing):
        cpos = self.map_to_canvas(mpos)

        if thing in self._elems:
            elem = self._elems[thing]
            if cpos != tuple(elem.pos):
                anim = Animation(pos=cpos, duration=0.2, t="in_out_sine")
                anim.start(elem)
        else:
            elem = MapElement(text=thing.char, pos=cpos)
            self._elems[thing] = elem
            self.add_widget(elem)

    def init_rects(self, *args):
        # we do our best to recycle the old rectangles
        if self.rects:
            for rect in self.rects:
                rect.source = self.cache.img_source(None)
            old_rects = self.rects
        else:
            old_rects = None
            
        w, h = self.map.size()
        self.rects = Array(w, h)

        with self.canvas:
            for mx in range(w):
                for my in range(h):
                    pos = self.map_to_canvas((mx, my))
                    source = self.cache.img_source(self.map[mx, my])
                    # TODO: reuse and old rect if possible
                    if old_rects:
                        r = old_rects.pop()
                        r.pos = pos
                        r.source = source
                    else:
                        r = Rectangle(pos=pos, 
                                      size=(TILE_SIZE, TILE_SIZE), 
                                      source=source)
                    self.rects[mx, my] = r

    def map_to_canvas(self, pos):
        """ Convert an (x, y) tile reference to a pixel position on the canvas.
        
        Return the bottom left corner of the rectangle representing the tile.
        """
        mx, my = pos
        return (mx*TILE_SIZE, my*TILE_SIZE)
        
    def canvas_to_map(self, pos):
        """ Convert an (x, y) canvas pixel coordinate into a map tile reference. 
        """
        cx, cy = pos
        return (cx//TILE_SIZE, cy//TILE_SIZE)

    def refresh_map(self, *args):
        """ Refresh the display of the map with actors and items. """
        if tender.engine.map is not self.map:
            self.set_map(tender.engine.map)
        
        # TODO refresh all the ground tiles
        seen = set()
                    
        for mpos, actor in self.map.iter_actors():
            seen.add(actor)
            self._update_elem(mpos, actor)
        for mpos, stack in self.map.iter_items():
            if stack:
                seen.add(stack)
                self._update_elem(mpos, stack)
                actor = self.map.actor_at(mpos)
                if actor:
                    opa = 0
                else:
                    opa = 1
                if opa != self._elems[stack].opacity:
                    anim = Animation(opacity=opa, duration=0.3)
                    anim.start(self._elems[stack])
        gone = set(self._elems.keys()) - seen
        for thing in gone:
            self._clear_elem(thing)

    def on_parent(self, widget, parent):
        self.focus = True
    
    def keyboard_on_key_down(self, window, key, text, modifiers):
        key_map = {"right": "move_or_act_right", 
                   "left": "move_or_act_left", 
                   "up": "move_or_act_up", 
                   "down": "move_or_act_down", 
                   "f": "follow-stairs",
                   "p": "pickup_item",
                   }

        res = None
        kcode, kname = key
        if kname in key_map:
            funct = tender.action_map[key_map[kname]]
            res = funct()
            if is_action(res):
                tender.hero.set_played()
                self.hero_turn = tender.hero.last_action
                tender.engine.advance_turn()
                self.engine_turn = tender.engine.current_turn
            return True
        else:
            return super().keyboard_on_key_down(window, key, text, modifiers)


class Controller(FloatLayout):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.bind(on_key_down=self.on_key_down)

    def on_parent(self, widget, parent):
        self.focus = True
    
    def on_key_down(self, key, **kwargs):
        print(f"key_down: {key} {kwargs!r}")


class DemoApp(App):
    def __init__(self, map, npc_callback, *args):
        super(DemoApp, self).__init__(*args)
        self.map = map
        self.npc_callback = npc_callback

    def set_map(self, map):
        self.map = map
        self.map_wid.set_map(map)
        
    def build(self):
        cont = Controller()
        self.map_wid = MapWidget(map=self.map, do_rotation=False)

        self.map_wid.bind(engine_turn=self.npc_callback)
        self.map_wid.bind(engine_turn=self.map_wid.refresh_map)
        self.map_wid.bind(hero_turn=self.npc_callback)
        self.map_wid.bind(hero_turn=self.map_wid.refresh_map)
        
        cont.add_widget(self.map_wid)
        return cont

from .governor import Condenser
def main():
    kivy.require('2.0.0')
    resources.resource_add_path("revengate/data/images/")
    
    condenser = Condenser()
    builder = condenser.random_builder()
    builder.staircase(char=">")
    builder.staircase(char="<")
    
    map = builder.map
    loader = TopLevelLoader()
    with data_file("core.toml") as f:
        loader.load(f)
    for name in ["pen", "sword"]:
        item = loader.invoke(name)
        map.place(item)
    rat = loader.invoke("rat")
    map.place(rat)
    pos = map.find(rat)
    print(f"rat at {pos}")

    DemoApp(map).run()


if __name__ == "__main__":
    main()    
