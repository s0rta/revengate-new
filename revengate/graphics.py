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
from kivy.properties import ObjectProperty, StringProperty
from kivy.uix.floatlayout import FloatLayout
from kivy.uix.scatter import Scatter
from kivy.graphics import Color, Rectangle
from kivy.uix.behaviors.focus import FocusBehavior
from kivy import resources

from .maps import TileType, Map, Builder
from .loader import DATA_DIR

# TileType -> path
IMG_TILE = {TileType.SOLID_ROCK: "dungeon/floor/lair_1_new.png", 
            TileType.FLOOR: "dungeon/floor/rect_gray_1_old.png", 
            TileType.WALL: "dungeon/wall/brick_brown_0.png", 
            TileType.DOORWAY_OPEN: "dungeon/open_door.png"}
TILE_SIZE = 32


class ImgSourceCache:
    def __init__(self):
        resources.resource_add_path(os.path.join(DATA_DIR, "images"))
        self._cache = {}            

    def texture_key(self, thing):
        if thing in TileType:
            return thing
        else: 
            raise TypeError(f"Unsupported type for texture conversion {type(thing)}")

    def img_source(self, thing):
        key = self.texture_key(thing)
        if key not in self._cache:
            self.load_image(thing)
        return self._cache[key]
        
    def load_image(self, thing):
        if thing in IMG_TILE:
            path = IMG_TILE[thing]
            fq_path = resources.resource_find(path)
            self._cache[thing] = fq_path
            return fq_path
        else:
            raise TypeError(f"Unsupported type for texture conversion {type(thing)}")
            

class MapWidget(FocusBehavior, Scatter):
    """ A widget to display a dungeon with graphical tiles. 
    
    Two coordinate systems are used:
    - map: tile id (map.tiles[x][y]), convention is (mx, my)
    - canvas: pixel position on the canvas, convition is (cy, cy)
    Both systems have (0, 0) at the bottom-left corner.
    """
    def __init__(self, map, *args, **kwargs):
        w, h = map.size()
        size = (w*TILE_SIZE, h*TILE_SIZE)
        super().__init__(*args, size=size, **kwargs)
        self.is_focusable = True
        self.map = map
        # pre-load all the textures
        self.cache = ImgSourceCache()
        self.init_rects()
        with self.canvas:
            self.hero = Label(text="@", font_size="28sp", size=(TILE_SIZE, TILE_SIZE))
    
    def init_rects(self, *args):
        self.rects = []
        w, h = self.map.size()

        with self.canvas:
            for mx in range(w):
                row = []
                for my in range(h):
                    pos = self.map_to_canvas((mx, my))
                    source = self.cache.img_source(self.map[mx, my])
                    r = Rectangle(pos=pos, 
                              size=(TILE_SIZE, TILE_SIZE), 
                              source=source)
                    row.append(r)
                self.rects.append(row)

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

    def on_parent(self, widget, parent):
        self.focus = True
    
    def keyboard_on_key_down(self, window, key, text, modifiers):
        kcode, kname = key
        if kname in ["right", "left", "up", "down"]:
            if kname == "right":
                self.hero.x += TILE_SIZE
            elif kname == "left":
                self.hero.x -= TILE_SIZE
            elif kname == "up":
                self.hero.y += TILE_SIZE
            elif kname == "down":
                self.hero.y -= TILE_SIZE
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
    def __init__(self, map, *args):
        super(DemoApp, self).__init__(*args)
        self.map = map
        
    def build(self):
        cont = Controller()
        map_wid = MapWidget(self.map, do_rotation=False)
        cont.add_widget(map_wid)
        return cont


from .governor import Condenser
def main():
    kivy.require('2.0.0')
    resources.resource_add_path("revengate/data/images/")
    
    condenser = Condenser()
    builder = condenser.random_builder()
    map = builder.map
    
    #map = Map()
    #builder = Builder(map)
    #builder.init(40, 20)
    #builder.room((5, 5), (35, 15), True)

    DemoApp(map).run()


if __name__ == "__main__":
    main()
    
