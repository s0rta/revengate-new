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
            for x in range(w):
                row = []
                for y in range(h):
                    pos = (x*TILE_SIZE, y*TILE_SIZE)
                    t = self._tex[self.map.tiles[x][y]]
                    r = Rectangle(pos=pos, 
                              size=t.size, 
                              texture=t)
                    row.append(r)
                self.rects.append(row)
                            

class DemoApp(App):
    def __init__(self, map, *args):
        super(DemoApp, self).__init__(*args)
        self.map = map
        
    def build(self):
        cont = FloatLayout()
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
    
