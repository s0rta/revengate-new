# Copyright © 2020–2022 Yannick Gingras <ygingras@ygingras.net> and contributors

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
from functools import wraps
import asyncio

import kivy
from kivymd.app import MDApp
from kivy.utils import platform
from kivy.vector import Vector
from kivy.uix.label import Label
from kivy.properties import (NumericProperty, StringProperty, ObjectProperty,            
                             BooleanProperty)
from kivy.uix.floatlayout import FloatLayout
from kivy.uix.scatter import ScatterPlane
from kivy.graphics import Rectangle
from kivy.uix.behaviors.focus import FocusBehavior
from kivy import resources
from kivy.animation import Animation
from kivy.uix.screenmanager import ScreenManager, ShaderTransition
from kivy.input.motionevent import MotionEvent
from kivymd.uix.label import MDLabel
import asynckivy as ak

from .maps import TileType, Connector
from .commands import CommandMap
from .loader import DATA_DIR
from .events import (Events, is_action, is_move, iter_events, Conversation, Death, 
                     Teleport, Injury, HealthEvent)
from .utils import Array
from .tags import t
from . import geometry as geom
from . import tender, forms

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
WINDOW_SIZE = (1280, 720)
WINDOW_SIZE_WIDE = (2164, 1080)

DEF_ICON_OPACITY = 0.7
ACTIVE_ICON_OPACITY = 1.0

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


def is_mobile():
    """ Return whether we are running on a mobile device. """
    return platform in ("ios", "android")


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


def syncify(funct):
    """ Convert a coroutine into a synchronous stub that uses asynckivy to invoke 
    launch the async processing. 
    
    The stub function returns an asynckivy.Task when called. 
    """
    
    @wraps(funct)
    def sync_funct(*args, **kwargs):        
        return ak.start(funct(*args, **kwargs))

    return sync_funct


def cancelable_selection(funct):
    """ Decorator to mark a selection method at cancelable. """
    @wraps(funct)
    def helper(self, *args, **kwargs):
        task = funct(self, *args, **kwargs)
        self._selection_tasks.add(task)
        return task
    return helper


def clear_selection_label(coro):
    """ Ensures that the coroutine will clear the selection label, even if it gets 
    cancelled. """
    @wraps(coro)
    async def helper(self, *args, **kwargs):
        try:
            return await coro(self, *args, **kwargs)
        finally:
            self._update_selection_lbl(text="")
    return helper


def async_turn_actions(coro):
    """ Process the turn actions of a coroutine wherever they become available. """
    @wraps(coro)
    async def helper(self, *args, **kwargs):
        res = await coro(self, *args, **kwargs)
        if is_action(res):
            self.finalize_turn(res)
        return res
    return helper


class MapWidget(FocusBehavior, ScatterPlane):
    """ A widget to display a dungeon with graphical tiles. 
    
    Two coordinate systems are used:
    - map: tile id (map.tiles[x][y]), convention is (mx, my)
    - canvas: pixel position on the canvas, convention is (cy, cy)
    Both systems have (0, 0) at the bottom-left corner.
    """
    
    engine_turn = NumericProperty(defaultvalue=None)  # turn currently being played
    hero_turn = NumericProperty(defaultvalue=None)  # last turn the hero did an action
    app = ObjectProperty(None)
    _next_selection_action = ObjectProperty(None, allownone=True)
    
    def __init__(self, *args, map=None, **kwargs):
        if map is not None:
            w, h = map.size()
            size = (w*TILE_SIZE, h*TILE_SIZE)
            kwargs["size"] = size
        super().__init__(*args, **kwargs)
        self.map = map
        self.is_focusable = not is_mobile()

        # pre-load all the textures
        self.cache = ImgSourceCache()
        self._elems = {}  # thing -> MapElement with thing being Actor or ItemCollection
        self.rects = []
        if map is not None:
            self.init_rects()
            self.refresh_map()

        # keep track of the keys we already took care of
        self._processed_keys = set()  
        
        self.key_map = None
        self.bind(app=self._init_key_map)

        self._selection_tasks = set()
        self.bind(_next_selection_action=self._update_selection_lbl)

    def _expand_multi_keys(self, key_map):
        """ De-normalize the keyboard actions that have more that one key into 
        {single_key:action} layout for fast lookup. """
        items = []
        for key, value in key_map.items():
            if isinstance(key, tuple):
                items += [(sub_key, value) for sub_key in key]
            else:
                items.append((key, value))
        return dict(items)
        
    def _init_key_map(self, *args):
        key_map = {("f2", "?"): self._print_help,
                   ("right", "l", 1073741903): "move-or-act-right", 
                   ("left", "h", 1073741904): "move-or-act-left", 
                   ("up", "k", 1073741906): "move-or-act-up", 
                   ("down", "j", 1073741905): "move-or-act-down", 
                   "f": self.follow_stairs,
                   "p": "pickup-item", 
                   "escape": self._cancel_selection_tasks} 
        
        if self.app.cheats:
            cheats = {"t": self._start_teleport, 
                      "6": self._start_insta_kill, 
                      "f5": self._start_debug_inspect}
            key_map.update(cheats)
        self.key_map = self._expand_multi_keys(key_map)
    
    def _update_selection_lbl(self, *args, text=None):
        if text is None: 
            if self._next_selection_action is None:
                text = ""
            else:
                text = str(self._next_selection_action)
        self.app.root.select_mode_lbl.text = text

    def _cancel_selection_tasks(self):
        """ Cancel all pending async selection tasks. """
        for task in self._selection_tasks:
            task.cancel()
        self._selection_tasks.clear()            
    
    def _print_help(self, *args):
        pprint(self.key_map)
        
    def _has_no_grab(self, widget, event):
        return event.grab_current is None
        
    def _no_drab_no_grab(self, widget, event):
        return self.is_not_drag(widget, event) and self._has_no_grab(widget, event)
        
    def description_at(self, there):
        map = tender.engine.map
        lines = []
        
        actor = map.actor_at(there)
        if actor:
            lines.append(f"{actor} is here.".capitalize())
        
        items = map.items_at(there)
        if items:
            top = items.top()
            if lines:
                lines.append(f"There is also a {top.name}.")
            else:
                lines.append(f"There is a {top.name} here.")
        
        mood = map.mood_at(there)
        if mood:
            lines.append(f"You notice {mood}.")
        return "\n".join(lines), mood
        
    @cancelable_selection
    @syncify
    @clear_selection_label
    async def start_look(self, button):
        button.opacity = ACTIVE_ICON_OPACITY
        try:
            self._update_selection_lbl(text="Looking...")
            wid, event = await ak.event(self, "on_touch_up", 
                                        filter=self._no_drab_no_grab, 
                                        stop_dispatching=True)
            there = self.canvas_to_map(event)
            desc, mood = self.description_at(there)
            tender.messages.append(desc, mood=mood)
            
            cont = self.app.root.messages_lbl_cont
            label = MDLabel(text=desc)
            cont.add_widget(label)
            
            # make it decay
            await ak.sleep(5)
            await ak.animate(label, opacity=0, d=1)
            cont.remove_widget(label)
        finally:
            button.opacity = DEF_ICON_OPACITY
    
    @cancelable_selection
    @syncify
    @clear_selection_label
    async def start_stats(self, button):
        self._update_selection_lbl(text="select monster...")
        wid, event = await ak.event(self, "on_touch_up", 
                                    filter=self._no_drab_no_grab, 
                                    stop_dispatching=True)
        # TODO: center the ripple effect on the monster, not on the stats button
        # self.app.center_on_button(event.pos)
        map = tender.engine.map
        there = self.canvas_to_map(event)
        them = map.actor_at(there)
        
        stats = tender.hero.perceived_stats(them)
        
        # fill the stats page
        screen = self.app.root.ids.stats_screen

        screen.stats_img.source = them.bestiary_img or EMPTY_IMG
        screen.stats_name_lbl.text = f"Name: {stats['name']}"
        screen.stats_str_lbl.text = f"Strength: {stats['strength']}"
        screen.stats_ag_lbl.text = f"Agility: {stats['agility']}"
        screen.stats_desc_lbl.text = them.desc

        # show the stats page
        self.app.root.current = "stats_screen"
        
    @cancelable_selection
    @syncify
    @async_turn_actions
    @clear_selection_label
    async def _start_teleport(self):
        self._update_selection_lbl(text="Teleporting...")
        wid, event = await ak.event(self, "on_touch_up", filter=self.is_not_drag)

        here = tender.engine.map.find(tender.hero)
        there = self.canvas_to_map(event)
        tender.engine.map.move(tender.hero, there)
        return Teleport(tender.hero, here, there)
        
    def _start_insta_kill(self):
        self._next_selection_action = self._insta_kill_at

    def _start_debug_inspect(self):
        self._next_selection_action = self._debug_at
        
    def _debug_at(self, there):
        actor = tender.engine.map.actor_at(there)
        if actor:
            print(f"inspecting {actor}")
            actor.debug_inspect()
        else:
            breakpoint()

    def _insta_kill_at(self, there):
        foe = tender.engine.map.actor_at(there)
        dmg = foe.health
        death = foe.suffer_damage(dmg)
        return Events(Injury(foe, dmg), death)
            
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
        self.center_on_hero()
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
        
        If pos is a Kivy event, then the coordinate is also converted to local canvas 
        coordinates before converting to map coordiates.
        """
        if isinstance(pos, MotionEvent):
            pos = self.to_local(*pos.pos)
        cx, cy = pos
        return (int(cx//TILE_SIZE), int(cy//TILE_SIZE))

    def refresh_map(self, *args):
        """ Refresh the display of the map with actors and items. """
        if tender.engine.map is not self.map:
            self.set_map(tender.engine.map)
        
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

    
    def drag_dist(self, touch_event):
        """ Return the scale adjusted magnitude for a touch drag event. """
        return sqrt(touch_event.dx**2 + touch_event.dy**2) / self.scale
        
    def is_drag(self, wid, touch_event):
        """ Return if we have reasons to believe that the event is a drag rather than a 
        tap.

        There is no hard science to this and our guess might be wrong at times.
        """
        if wid == self:
            duration = touch_event.time_end - touch_event.time_start
            return self.drag_dist(touch_event) > 2.0 or duration > 0.2
        else:
            return False
        
    def is_not_drag(self, wid, touch_event):
        return not self.is_drag(wid, touch_event)
        
    def on_touch_down(self, event):
        if event.device == "mouse":
            if event.button == "scrolldown":
                self.scale *= 1.1
                return True
            elif event.button == "scrollup":
                self.scale /= 1.1
                return True
        return super().on_touch_down(event)
        
    def on_touch_up(self, event):
        if not tender.hero or tender.hero.is_dead:
            return False
        if not event.grab_state and not self.is_drag(self, event):
            res = None
            cpos = self.to_local(*event.pos)
            mpos = self.canvas_to_map(cpos)
            if self._next_selection_action is not None:
                res = self._next_selection_action(mpos)
                self._next_selection_action = None
            else:
                hero_pos = self.map.find(tender.hero)
                if mpos in self.map.adjacents(hero_pos, free=False):
                    direction = Vector(mpos) - Vector(hero_pos)
                    res = tender.commands["move-or-act"](direction)
            if is_action(res):
                self.finalize_turn(res)
                return True
        return super().on_touch_up(event)
    
    def _try_key_command(self, kname):
        """ Try to perform the keyboard action associated with kname (char or long name 
        of a key). Return wheter an action was performed, regardless of the success of 
        said action."""
        if not tender.hero or tender.hero.is_dead:
            return False
        if kname in self.key_map:
            if callable(self.key_map[kname]):
                funct = self.key_map[kname]
            else:
                funct = tender.commands[self.key_map[kname]]
            res = funct()
            if is_action(res):
                self.finalize_turn(res)
            return True
        return False
    
    def keyboard_on_textinput(self, window, text):
        # handle litteral keys with the modifier applied by Kivy. ex.: "Shift+/" -> "?"
        if text not in self._processed_keys and self._try_key_command(text):
            return True
        else:
            return super().keyboard_on_textinput(window, text)
    
    def keyboard_on_key_down(self, window, key, text, modifiers):
        # handle things like arrow keys
        kcode, kname = key
        if self._try_key_command(kname or kcode):
            self._processed_keys.add(kname or kcode)
            return True
        else:
            return super().keyboard_on_key_down(window, key, text, modifiers)

    def keyboard_on_key_up(self, window, key):
        kcode, kname = key
        self._processed_keys.discard(kname or kcode)

    def center_on_hero(self, anim=False):
        """ Move the tiles to have the hero at the center of the screen. """
        if not tender.hero or not tender.engine.map:
            return
        
        mpos = tender.engine.map.find(tender.hero)
        cpos = Vector(self.map_to_canvas(mpos))
        spos = cpos * self.scale
        
        center = Vector(self.parent.size) / 2
        delta = center - spos        
        if anim:
            anim = Animation(pos=delta, duration=0.2)
            anim.start(self)
        else:
            self.pos = delta
        
    def verify_centering(self, anim=False):
        """ See if we should recenter the screen on the hero, do so if needed. """
        mpos = tender.engine.map.find(tender.hero)
        cpos = Vector(self.map_to_canvas(mpos))
        ppos = self.to_parent(*cpos)
        
        cut_dist = 2.5*TILE_SIZE*self.scale
        cutoff = Vector(cut_dist, cut_dist)
        top_right = Vector(self.parent.size) - cutoff
        if not Vector.in_bbox(ppos, cutoff, top_right):
            self.center_on_hero(anim)
        
    async def animate_health_event(self, event):
        """ Animate a health event, which is typically the result of an attack. """
        red = "#DD1010"
        if event.victim in self._elems:
            v_elem = self._elems[event.victim]
        else:
            return
        if hasattr(event, "attacker") and event.attacker in self._elems:
            a_elem = self._elems[event.attacker]
            # calling tuple() because we need a copy or the value will change under our 
            # feet
            old_pos = tuple(a_elem.pos)  
            mid_point = geom.mid_point(a_elem.pos, v_elem.pos)
            await ak.animate(a_elem, pos=mid_point, d=0.1)
            retreat = ak.animate(a_elem, pos=old_pos, d=0.2)
        else:
            retreat = ak.sleep(0)

        with self.canvas:
            rect = MapElement(text="◯", pos=v_elem.pos, opacity=0.3, 
                              color=red, outline_color=red, outline_width=0)
            fade_in = ak.animate(rect, font_size=rect.font_size*1.3, outline_width=3,
                                 opacity=.7, d=0.3)
            await ak.and_(retreat, fade_in)
            await ak.animate(rect, font_size=rect.font_size*1.3, outline_width=0,
                             opacity=0, d=0.3)

    def finalize_turn(self, events=None):
        """ Let all NPCs play, update all statuses, refresh map.
        
        events: if supplied, a collection of status events that will be displayed.
        
        Call this after every hero actions. 
        """
        if events:
            if is_move(events):
                mpos = tender.engine.map.find(tender.hero)
                mood = tender.engine.map.mood_at(mpos)
                if mood:
                    print(mood)
                self.verify_centering(anim=True)
            self.app.display_status_events(events)

        # if the hero hasn't killed themself, trigger the NPC turn
        if tender.hero and tender.hero.is_alive:
            self.hero_turn = tender.hero.last_action

        if tender.engine:
            events = tender.engine.advance_turn()
            self.app.display_status_events(events)
            
        if tender.engine:
            tender.commands["save-game"]()
            self.engine_turn = tender.engine.current_turn

    def rest(self, *args):
        res = tender.hero.rest()
        self.finalize_turn(res)

    def loot(self, *args):
        res = tender.commands["pickup-item"]()
        if is_action(res):
            self.finalize_turn(res)
        return True

    def follow_stairs(self, *args):
        res = tender.commands["follow-stairs"]()
        if is_action(res):
            self.finalize_turn(res)
        return True


class UICommands(CommandMap):
    def __init__(self, name, app):
        self.app = app
        super().__init__(name, prefix="ui-")

    def show_value(self, value, response_funct=None):
        value_popup = forms.ShowValuePopup(str(value), response_funct)
        value_popup.open()


class RevScreenManager(ScreenManager):
    map_wid = ObjectProperty(None)


class RipplesTransition(ShaderTransition):
    TRANSITION_FS = '''$HEADER$
    uniform float t;
    uniform sampler2D tex_in;
    uniform sampler2D tex_out;

    const vec2 eff_center = vec2(%f, %f);
    const float PI = 3.141592653589793;
    const float ROOT_2 = 1.4142135623730951;
    const float RING_W = 0.35;
    const float EFFECT_SLOPE = -1.0/RING_W;

    // cos() compressed and translated up to be in 0..1
    float pos_cos(float theta) {
        return 0.5+cos(theta)*0.5;
    }

    void main(void) {
        // must end at an integer boudary to yeild cos(theta)=1
        const float nb_periods = 2.0;
        const float theta_max = 2.0 * nb_periods * PI;

        float max_bl_tr = max(distance(eff_center, vec2(0.0)), 
                              distance(eff_center, vec2(1.0)));
        float max_tl_br = max(distance(eff_center, vec2(0.0, 1.0)), 
                              distance(eff_center, vec2(1.0, 0.0)));
        float max_r = max(max_bl_tr, max_tl_br);

        // scaled distance to the centre of effect in 0..1
        float r = distance(tex_coord0, eff_center) / max_r;

        // stretch time a little bit so the effect gets to complete rather than 
        // aborting when it starts touching the edges
        float fast_t = t * (1.0+RING_W);  

        float effect_zone = clamp((r - fast_t) * EFFECT_SLOPE, 0.0, 1.0);
        
        float wave_height = pos_cos(effect_zone*theta_max);
        float mix_pct = effect_zone * wave_height;
        
        // refraction
        vec2 offset = vec2(0.0);
        if (wave_height < 0.3) {
            offset = vec2(0.01);
        }
           
        vec4 current = texture2D(tex_out, tex_coord0-offset);
        vec4 next = texture2D(tex_in, tex_coord0-offset);
        
        gl_FragColor = mix(current, next, mix_pct);
    }
    '''
    fs = StringProperty(None)

    def __init__(self, app):
        self.app = app
        self.clearcolor = self.app.theme_cls.bg_normal
        super().__init__()

    def update_eff_center(self, eff_center):
        x, y = eff_center
        w, h = self.app.root.size
        sx, sy = 1.0 * x / w, 1.0 * y / h
        self.fs = self.TRANSITION_FS % (sx, sy)

    def center_on_button(self, button=None):
        if button:
            eff_center = button.last_touch.pos
        else:
            eff_center = self.app.root.center
        self.update_eff_center(eff_center)


class RevengateApp(MDApp):
    has_hero = BooleanProperty(False)
    hero_name = StringProperty(None)
    hero_name_form = ObjectProperty(None)
    
    def __init__(self, cheats=False, *args):
        self.cheats = cheats
        super().__init__(*args)
        resources.resource_add_path(os.path.join(DATA_DIR, "images"))
        resources.resource_add_path(os.path.join(DATA_DIR, "fonts"))

        ui_cmds = UICommands("UI Commands", app=self)
        tender.commands.register_sub_map(ui_cmds)

    def has_saved_game(self):
        return tender.commands["has-saved-game"]()
        
    def show_narration(self, dialogue, response_funct=None):
        popup = forms.ConversationPopup(dialogue, response_funct)
        popup.open()

    def show_conversation(self, dialogue, response_funct=None):
        # TODO: pause time
        popup = forms.ConversationPopup(dialogue, response_funct)
        popup.open()

    async def start_new_game_coro(self):
        if not self.hero_name_form:
            self.hero_name_form = forms.HeroNameForm()
        values = await self.hero_name_form.values_when_ready()

        if values is not None and "hero_name" in values:
            tender.commands["new-game-response"](values["hero_name"])
            self.map_wid.set_map(tender.engine.map)
            self.root.current = "map_screen"
            
            dialogue = tender.loader.invoke(t("intro"))
            self.show_narration(dialogue)

    def start_new_game(self):
        ak.start(self.start_new_game_coro())

    def set_map(self, map):
        self.map_wid.set_map(map)
        
    def focus_map(self):
        if self.map_wid.is_focusable:
            self.map_wid.focus = True    

    def show_stats_screen(self, button=None):
        self.root.transition.center_on_button(button)
        
        self.root.current = "stats_screen"

    def show_map_screen(self, button=None):
        self.root.transition.center_on_button(button)
        
        if not tender.hero or tender.hero.is_dead or not tender.engine.map:
            tender.commands["restore-game"]()
        self.map_wid.set_map(tender.engine.map)
        self.root.current = "map_screen"

    def show_main_screen(self, button=None):
        self.root.transition.center_on_button(button)
        
        if tender.hero and tender.hero.is_alive:
            tender.commands["save-game"]()
        self.root.resume_game_bt.disabled = not tender.commands["has-saved-game"]()

        self.root.current = "main_screen"
    
    def display_status_events(self, events):
        for event in iter_events(events):
            if isinstance(event, Injury):
                ak.start(self.map_wid.animate_health_event(event))
            if isinstance(event, Conversation):
                convo = tender.loader.invoke(event.tag)
                self.show_conversation(convo)
            elif isinstance(event, Death) and event.actor == tender.hero:
                print(event)
                tender.commands["purge-game"]()
                form = forms.GameOverPopup(self.show_main_screen)
                form.open()
            else:
                # TODO: put in a scrollable view on the MapWidget
                print(event)
    
    def play_npcs_and_refresh(self, *args):
        events = tender.commands["npc-turn"]()
        self.map_wid.refresh_map()
        self.display_status_events(events)
    
    def stop(self):
        if tender.hero and tender.hero.is_alive:
            tender.commands["save-game"]()   
        super().stop()
        
    def build(self):
        super().build()
        self.theme_cls.theme_style = "Dark"
        self.theme_cls.material_style = "M3"
        self.theme_cls.primary_palette = "Amber"
        self.theme_cls.accent_palette = "Brown"

        self.root.transition = RipplesTransition(self)
        self.root.transition.duration = 1.0

        self.map_wid = self.root.map_wid
        self.map_wid.bind(engine_turn=self.play_npcs_and_refresh)
        self.map_wid.bind(hero_turn=self.play_npcs_and_refresh)

        # TODO: disable "resume" button unless there is a saved game

        return self.root

    def on_start(self):
        if platform == "linux":
            self.root_window.size = WINDOW_SIZE
        return super().on_start()
