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

from pprint import pprint
import kivy
from kivy.app import App
from kivy.core.window import Window
from kivy.core.text import Label as CoreLabel
from kivy.uix.widget import Widget
from kivy.uix.label import Label
from kivy.uix.button import Button
from kivy.uix.image import Image
from kivy.properties import ObjectProperty, StringProperty
from kivy.uix.floatlayout import FloatLayout
from kivy.uix.scatter import Scatter
from kivy.graphics import Color, Rectangle
from kivy import resources

from .maps import TileType, Map, Builder

# TileType -> path
TILE_SIZE = 32
IMG_TILE = {TileType.SOLID_ROCK: "dungeon/floor/lair_1_new.png", 
            TileType.FLOOR: "dungeon/floor/rect_gray_1_old.png", 
            TileType.WALL: "dungeon/wall/brick_brown_0.png"}


class MapWidget(Scatter):
    """ A widget to display a dungeon with graphical tiles. 
    
    Two coordinate systems are used:
    - map: tile id (map.tiles[x][y]), convention is (mx, my)
    - canvas: pixel position on the canvas, convition is (cy, cy)
    Both systems have (0, 0) at the bottom-left corner.
    """
    def __init__(self, map, *args, **kwargs):
        w, h = map.size()
        size = (w*TILE_SIZE, h*TILE_SIZE)
        super(MapWidget, self).__init__(*args, size=size, **kwargs)
        self.map = map
        # pre-load all the textures
        self._tex = {} # TileType->texture map
        for t_type, path in IMG_TILE.items():
            fq_path = resources.resource_find(path)
            self._tex[t_type] = Image(source=fq_path).texture
        
        self.init_rects()
    
    def init_rects(self, *args):
        self.rects = []
        w, h = self.map.size()

        with self.canvas:
            for mx in range(w):
                row = []
                for my in range(h):
                    pos = self.map_to_canvas((mx, my))
                    t = self._tex[self.map.tiles[mx][my]]
                    r = Rectangle(pos=pos, 
                              size=t.size, 
                              texture=t)
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


class Controller(FloatLayout):
    def __init__(self, *args, **kwargs):
        super(Controller, self).__init__(*args, **kwargs)
        self._keyboard = Window.request_keyboard(self._keyboard_closed, self)
        self._keyboard.bind(on_key_down=self.on_key_down)

    def _keyboard_closed(self):
        self._keyboard.unbind(on_key_down=self.on_key_down)
        self._keyboard = None
    
    def on_key_down(self, kb, key, scancode, codepoint, modifier, **kwargs):
        print(f"key_down: {key}")


class DemoApp(App):
    def __init__(self, map, *args):
        super(DemoApp, self).__init__(*args)
        self.map = map
        
    def build(self):
        cont = Controller()
        map_wid = MapWidget(self.map, do_rotation=False)
        cont.add_widget(map_wid)
        return cont


def main():
    kivy.require('2.0.0')
    resources.resource_add_path("revengate/data/images/")
    
    map = Map()
    builder = Builder(map)
    builder.init(40, 20)
    builder.room(5, 5, 35, 15, True)

    
    DemoApp(map).run()


if __name__ == "__main__":
    main()
    
