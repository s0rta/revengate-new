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
from math import sqrt

import kivy
from kivymd.app import MDApp
from kivy.utils import platform
from kivy.core.window import Window
from kivy.core.text import Label as CoreLabel
from kivy.graphics.texture import Texture
from kivy.uix.widget import Widget
from kivy.uix.label import Label
from kivy.uix.button import Button
from kivy.uix.image import Image
from kivy.uix.textinput import TextInput
from kivy.properties import (NumericProperty, StringProperty, ObjectProperty,            
                             BooleanProperty)
from kivy.uix.floatlayout import FloatLayout
from kivy.uix.scatter import Scatter, ScatterPlane
from kivy.graphics import Color, Rectangle
from kivy.uix.behaviors.focus import FocusBehavior
from kivy import resources
from kivy.animation import Animation
from kivy.uix.boxlayout import BoxLayout
from kivymd.uix.button import MDFlatButton
from kivymd.uix.dialog import MDDialog
from kivy.uix.screenmanager import ScreenManager, WipeTransition, ShaderTransition

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
        fname = "kalimati.ttf"
    else:
        fname = "Symbola_hint.ttf"
    return resources.resource_find(fname)


class MapElement(Label):
    def __init__(self, *args, **kwargs):
        text = kwargs.pop("text")
        size = (TILE_SIZE, TILE_SIZE)
        super().__init__(*args, text=text, 
                         font_size="28px", size=size, bold=True, 
                         font_name=best_font(text), 
                         **kwargs)
        

class MapWidget(FocusBehavior, ScatterPlane):
    """ A widget to display a dungeon with graphical tiles. 
    
    Two coordinate systems are used:
    - map: tile id (map.tiles[x][y]), convention is (mx, my)
    - canvas: pixel position on the canvas, convition is (cy, cy)
    Both systems have (0, 0) at the bottom-left corner.
    """
    
    engine_turn = NumericProperty(defaultvalue=None)  # turn currently being played
    hero_turn = NumericProperty(defaultvalue=None)  # last turn the hero did an action
    app = ObjectProperty(None)
    
    def __init__(self, *args, map=None, **kwargs):
        if map is not None:
            w, h = map.size()
            size = (w*TILE_SIZE, h*TILE_SIZE)
            kwargs["size"] = size
        super().__init__(*args, **kwargs)
        self.map = map
        self.is_focusable = platform not in ("ios", "android")
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
            with self.canvas:
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
        return (int(cx//TILE_SIZE), int(cy//TILE_SIZE))

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
    
    def drag_dist(self, touch_event):
        """ Return the scale adjusted magnitude for a touch drag event. """
        return sqrt(touch_event.dx**2 + touch_event.dy**2) / self.scale
        
    def is_drag(self, touch_event):
        """ Return if we have reasons to believe that the event is a drag rather than a 
        tap.

        There is no hard science to this and our guess might be wrong at times.
        """
        duration = touch_event.time_end - touch_event.time_start
        return self.drag_dist(touch_event) > 2.0 or duration > 0.2
        
    def on_touch_up(self, event):        
        if not self.is_drag(event):
            res = None
            cpos = self.to_local(*event.pos)
            mpos = self.canvas_to_map(cpos)
            hero_pos = self.map.find(tender.hero)
            if mpos in self.map.adjacents(hero_pos, free=True):
                res = tender.hero.move(mpos)
            elif mpos in self.map.adjacents(hero_pos, free=False):
                victim = self.map.actor_at(mpos)
                if victim:
                    res = tender.hero.attack(victim)
            if is_action(res):
                self.finalize_turn(res)
                return True
        return super().on_touch_up(event)
    
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
        if kname == "d":
            self.app.show_hero_name_dia()
            return True

        if kname in key_map:
            funct = tender.action_map[key_map[kname]]
            res = funct()
            if is_action(res):
                self.finalize_turn(res)
            return True
        else:
            return super().keyboard_on_key_down(window, key, text, modifiers)

    def finalize_turn(self, events=None):
        """ Let all NPCs play, update all statuses, refresh map.
        
        events: if supplied, a collection of status events that will be displayed.
        
        Call this after every hero actions. 
        """
        if events:
            # TODO: show those in a scrollable view pane
            print(events)
        self.hero_turn = tender.hero.last_action
        tender.engine.advance_turn()
        self.engine_turn = tender.engine.current_turn

    def rest(self, *args):
        res = tender.hero.rest()
        self.finalize_turn(res)


class Controller(FloatLayout):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

class RevDialog(MDDialog):
    app = ObjectProperty(None)

    
    def __init__(self, response_funct, content_cls, *args, **kwargs):
        self.response_funct = response_funct
        self.cancel_btn = MDFlatButton(text="CANCEL", on_release=self.dismiss)
        self.ok_btn = MDFlatButton(text="OK", 
                                   on_release=self.try_accept, 
                                   disabled=True)
        super().__init__(content_cls=content_cls, 
                         buttons=[self.cancel_btn, self.ok_btn])
        
    def form_values(self):
        """ Return the values contained in the form as a dictionnary. 
        
        Form fields must have a `data_name` attribute to be captired; `data_name` is 
        used as the key in the returned dictionnary. 
        """
        values = {}
        for wid in self.walk(restrict=True):
            if isinstance(wid, TextInput):
                if hasattr(wid, "data_name"):
                    values[wid.data_name] = wid.text
        return values
        
    def accept(self, *args, **kwargs):
        """ Dimiss the popup and consume the supplied data. """
        if self.response_funct:
            self.response_funct(**self.form_values())
        self.dismiss()

    def try_accept(self, *args, **kwargs):
        """ Accept the form if data is valid, refuse with visual feedback otherwise. 
        """
        if self.is_valid():
            self.accept()

    def is_valid(self, *args, **kwargs): 
        """ See if the supplied data is ready for consumption. """
        raise NotImplementedError()
    
    def validate(self, *args, **kwargs):
        """ See if the data is ready for consumption and adjust the UI to reflect that. 
        
        Subclasses are encouraged to overload this method to provide a richer 
        experience.
        """
        self.ok_btn.disabled = not self.is_valid()


class HeroNameDialog(RevDialog):
    def __init__(self, response_funct, *args, **kwargs):
        cont = HeroNameDialogContent()
        cont.ids.hero_name_field.bind(text=self.validate,
                                      on_text_validate=self.try_accept)
        super().__init__(response_funct, content_cls=cont)

    def is_valid(self, *args, **kwargs): 
        return bool(self.form_values()["hero_name"])


class HeroNameDialogContent(BoxLayout):
    pass


class RevScreenManager(ScreenManager):
    map_wid = ObjectProperty(None)


class DemoApp(MDApp):
    has_hero = BooleanProperty(False)
    hero_name = StringProperty(None)
    hero_name_dia = ObjectProperty(None)
    
    def __init__(self, map, npc_callback, *args):
        super(DemoApp, self).__init__(*args)
        self.map = map
        self.npc_callback = npc_callback
        resources.resource_add_path(os.path.join(DATA_DIR, "images"))
        resources.resource_add_path(os.path.join(DATA_DIR, "fonts"))

    def init_new_game(self, hero_name):
        tender.action_map["new-game-response"](hero_name)
        self.map_wid.set_map(tender.engine.map)
        self.root.current = "mapscreen"
        
    def show_hero_name_dia(self):
        if not self.hero_name_dia:
            self.hero_name_dia = HeroNameDialog(self.init_new_game)
        self.hero_name_dia.open()

    def set_map(self, map):
        self.map = map
        self.map_wid.set_map(map)
        
    def show_map_screen(self, *args):
        self.map_wid.set_map(tender.engine.map)
        self.root.current = "mapscreen"

    def show_main_screen(self, *args):
        if tender.hero and tender.hero.is_alive:
            tender.action_map["save-game"]
        self.root.current = "mainscreen"
    
    def stop(self):
        if tender.hero and tender.hero.is_alive:
            tender.action_map["save-game"]        
        super().stop()
        
    def build(self):
        super().build()
        self.root.transition = CoolTransition()
        self.root.transition.duration = 2.0
        self.theme_cls.theme_style = "Dark"
        self.theme_cls.material_style = "M3"
        self.theme_cls.primary_palette = "Amber"
        self.theme_cls.accent_palette = "Brown"

        self.map_wid = self.root.map_wid
        self.map_wid.bind(engine_turn=self.npc_callback)
        self.map_wid.bind(engine_turn=self.map_wid.refresh_map)
        self.map_wid.bind(hero_turn=self.npc_callback)
        self.map_wid.bind(hero_turn=self.map_wid.refresh_map)

        # TODO: disable "resume" button unless there is a saved game
        
        return self.root


class CoolTransition(ShaderTransition):
    # TODO: blank the background with the theme background color
    COOL_TRANSITION_FS = '''$HEADER$
    uniform float t;
    uniform sampler2D tex_in;
    uniform sampler2D tex_out;

    void main(void) {
        vec4 cin = texture2D(tex_in, tex_coord0);
        vec4 cout = texture2D(tex_out, tex_coord0);
        
        vec2 pos = tex_coord0 * 2.0 - 1.0;
        
        /*
        float val = clamp(t*2.0-length(pos), 0.0, 1.0);
        vec4 col = vec4(val, val, val, 1.0);
        gl_FragColor = col;
        */
         
        gl_FragColor = mix(cout, cin,
                           clamp(t*3.0-length(pos), 0.0, 1.0)
                          );
  
    }
    '''
    fs = StringProperty(COOL_TRANSITION_FS)


from .governor import Condenser
def main():
    kivy.require('2.0.0')
    resources.resource_add_path("revengate/data/images/")
    resources.resource_add_path("revengate/data/fonts/")
    
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
