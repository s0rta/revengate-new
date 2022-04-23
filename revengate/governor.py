# Copyright © 2022 Yannick Gingras <ygingras@ygingras.net> and contributors

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

""" Orchestrate all the pre-game logic. """


import os
import glob
import pickle

from . import tender
from .randutils import rng
from .loader import DATA_DIR, TopLevelLoader, data_path
from .engine import Engine
from .ui import TextUI, Quitting, KivyUI
from .action_map import ActionMap
from .maps import Connector
from .area import Area
from .events import is_action, StairsEvent
from .tags import t

from .graphics import RevengateApp


CONFIG_ROOT = os.environ.get("XDG_CONFIG_HOME", "~/.config")
CONFIG_DIR = os.path.join(CONFIG_ROOT, "revengate")
CORE_FILE = "core.tml"

# all the file keys you need to get a complete saved game
SAVED_GAME_KEYS = ["hero", "engine", "mapid", "dungeon"]

class Condenser:
    """ Save and reload game objects """

    @property
    def config_dir(self):
        # we resolve the globals every time to allow different plateforms to update them 
        # late during the startup
        return os.path.expanduser(CONFIG_DIR)

    def file_path(self, key):
        fname = f"{key}.pickle"
        return os.path.join(self.config_dir, "save", fname)
        
    def ensure_dir(self, path):
        if path.endswith("/"):
            dirname = path
        else:
            dirname = os.path.dirname(path)
        if not os.path.isdir(dirname):
            os.makedirs(dirname)

    def load(self, key):
        fpath = self.file_path(key)
        if not os.path.isfile(fpath):
            return None
        return pickle.load(open(fpath, "rb"))
    
    def save(self, key, obj):
        fpath = self.file_path(key)
        self.ensure_dir(fpath)
        pickle.dump(obj, open(fpath, "wb"))
    
    def delete(self, key):
        fpath = self.file_path(key)
        if os.path.isfile(fpath):
            os.unlink(fpath)

    def random_builder(self):
        maps_pat = os.path.join(DATA_DIR, "maps", "map-*.pickle")
        map_files = glob.glob(maps_pat)
        fname = rng.choice(map_files)
        return pickle.load(open(fname, "rb"))

    def has_file(self, key):
        fpath = self.file_path(key)
        return os.path.isfile(fpath)
    
    def has_saved_game(self):
        return all(map(self.has_file, SAVED_GAME_KEYS))

    def delete_game(self):
        for key in SAVED_GAME_KEYS:
            self.delete(key)


class Governor:
    def __init__(self):
        self.condenser = Condenser()
        tender.loader = TopLevelLoader()
        tender.loader.load(open(data_path(CORE_FILE), "rt"))
        tender.sentiments = tender.loader.get_instance("core_sentiments")
        self.dungeon = None

        # FIXME: move that somewhere else
        # self.restore_game()
        if tender.engine is None:
            tender.engine = Engine()
        
        tender.action_map = ActionMap()
        tender.action_map.register(self.follow_stairs)
        tender.action_map.register(self.new_game_response)
        tender.action_map.register(self.npc_turn)
        tender.action_map.register(self.save_game)
        tender.action_map.register(self.restore_game)
        tender.action_map.register(self.condenser.delete_game)
        tender.action_map.register(self.condenser.has_saved_game)
        
        tender.ui = KivyUI()
        self.app = RevengateApp(None, self.npc_turn)
        global CONFIG_DIR
        CONFIG_DIR = self.app.user_data_dir

    def save_game(self):
        self.condenser.save("engine", tender.engine)
        self.condenser.save("hero", tender.hero)
        self.condenser.save("mapid", tender.engine.map.id)
        self.condenser.save("dungeon", self.dungeon)
        
    def restore_game(self):
        tender.hero = self.condenser.load("hero")
        tender.engine = self.condenser.load("engine")
        self.dungeon = self.condenser.load("dungeon")
        mapid = self.condenser.load("mapid")
        
        if mapid is not None and tender.engine is not None:
            tender.engine.change_map(self.dungeon[mapid])

    def make_map(self, nb_monsters, item, from_pos=None, parent_map=None):
        lvl = len(self.dungeon.maps) + 1
        
        builder = self.condenser.random_builder()
        map = builder.map

        # stairs
        if lvl < 5:
            # after 5 levels, we can't go down anymore
            builder.staircase()
        else:
            # TODO: it would be convenient to be able to pass name directly to invoke()
            omandar = tender.loader.invoke("observer")
            omandar.name = "Omandar"
            omandar.next_dialogue = t("deepest_level")
            map.place(omandar)

        if parent_map:
            builder.staircase(None, "<", from_pos, parent_map)

        for name in rng.choices(["slime", "rat", "wolf"], k=nb_monsters):
            a = tender.loader.invoke(name)
            map.place(a)
        map.place(item)
        self.dungeon.add_map(map, parent_map)
        return map

    def make_first_map(self):
        pen = tender.loader.invoke("pen")
        map = self.make_map(2, pen)
        
        obs = tender.loader.invoke("observer")
        obs.next_dialogue = t("first_level")
                
        # FIXME: debug
        tender.obs = obs
        
        map.place(obs)
        tender.engine.change_map(map)
        if tender.hero:
            map.place(tender.hero)
        return map

    def start(self):
        """ Start a game. """
        self.app.run()
            
    def npc_turn(self, *args):
        """ Let all non-player actors do their turn, return if the hero is still alive.
        
        This function is no-op if actors have already played and the turn has not been 
        advanced on the engine.
        """
        for actor in tender.engine.all_actors():
            if actor.has_played or actor.is_dead:
                continue
            if actor is tender.hero and not tender.hero.has_played:
                return tender.hero.is_alive
            elif actor in tender.engine.map and not actor.has_played:
                event = actor.act()
                if event:
                    tender.ui.show_turn_events(event)
            if tender.hero.is_dead:
                return False

    def hero_turn(self):
        # not used anymore, only kept to illustate how self.play() works
        while not tender.hero.has_played:
            print(tender.engine.map.to_text())
            move = tender.ui.read_next_move()
            if is_action(move):
                tender.ui.show_turn_events(move)
                tender.hero.set_played()
        
    def play(self):
        """ Main game loop. 
        
        return True if the hero is still alive, False otherwise. 
        """
        # This game loop is obsolete, but it's usufull for showing what the event-based 
        # loop is emulating with its callbacks bound to app.engine_turn and 
        # app.hero_turn.

        done = False
        while not done:
            if tender.hero.is_dead:
                return False

            # There is an NPC turn before and after the hero's turn to cover for 
            # monsters with higher and lower initiatives respectively.
            self.npc_turn()
            self.hero_turn()
            self.npc_turn()
            if tender.hero.is_dead:
                self.condenser.delete_game()
                return False

            if tender.hero.has_played:
                events = tender.engine.advance_turn()
                print(events or "no turn updates")

        return True
            
    def new_hero_response(self, hero_name):
        self.condenser.save("hero", tender.hero)

    def new_game_response(self, hero_name):
        self.condenser.delete_game()
        self.dungeon = Area()

        # FIXME: we really should be able to pass the name to invoke()
        tender.hero = tender.loader.invoke("novice")
        tender.hero.name = hero_name

        map = self.make_first_map()
        self.dungeon.add_map(map, parent=None)
        self.save_game()
        
    def follow_stairs(self):
        from_pos = tender.engine.map.find(tender.hero)
        tile = tender.engine.map[from_pos]
        if isinstance(tile, Connector):
            print(f"following stairs at {from_pos}")
            mapid = tile.dest_map
            if mapid is None:
                sword = tender.loader.invoke("sword")
                map = self.make_map(3, sword, from_pos, tender.engine.map)
                
            else:
                map = self.dungeon[mapid]
            # switch the map
            next_pos = map.arrival_pos(tender.engine.map.id)
            tender.engine.map.remove(tender.hero)
            tender.engine.change_map(map)
            map.place(tender.hero, next_pos)

            tender.hero.set_played()
            return StairsEvent(tender.hero, from_pos)
        else:
            print(f"there are no stairs at {from_pos}")
            return None
        
    def shutdown(self):
        """ Gracefully shutdown after saving everything. """
        ...
