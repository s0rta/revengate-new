# Copyright © 2022 Yannick Gingras <ygingras@ygingras.net>

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
import shutil
import pickle

from . import tender
from .randutils import rng
from .loader import DATA_DIR, TopLevelLoader, data_path
from .engine import Engine
from .ui import TextUI, Quitting
from .action_map import ActionMap
from .maps import Map, Builder, Connector
from .area import Area
from .events import StatusEvent, Events

CONFIG_DIR = "~/.config/revengate"
CORE_FILE = "core.toml"

class Condenser:
    """ Save and reload game objects """

    def __init__(self):
        self.config_dir = os.path.expanduser(CONFIG_DIR)

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


class Governor:
    def __init__(self):
        self.condenser = Condenser()
        tender.loader = TopLevelLoader()
        tender.loader.load(open(data_path(CORE_FILE), "rt"))
        self.restore_game()
        if self.dungeon is None:
            self.dungeon = Area()
        if tender.engine is None:
            tender.engine = Engine()
        
        tender.ui = TextUI()
        tender.action_map = ActionMap()
        tender.action_map.register(self.follow_stairs, "follow-stairs")

    def del_game(self):
        for key in ["hero", "engine", "mapid", "dungeon"]:
            self.condenser.delete(key)

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
        map = Map(f"level {lvl}")
        builder = Builder(map)
        builder.init(60, 20)
        builder.room((5, 5), (20, 15), True)
        # FIXME: the inner room does not show up
        builder.room((12, 7), (13, 12), True)

        # stairs
        if lvl < 5:
            # we after 5 levels, we can't go down anymore
            builder.staircase()
        if parent_map:
            builder.staircase(None, "<", from_pos, parent_map)

        for name in rng.choices(["rat", "wolf"], k=nb_monsters):
            a = tender.loader.invoke(name)
            map.place(a)
        map.place(item)
        self.dungeon.add_map(map, parent_map)
        return map

    def start(self):
        """ Start a game. """
        if tender.hero is None:
            self.create_hero()
        
        # pre-game naration
        dia = tender.loader.get_instance("intro")
        tender.ui.show_dia(dia)

        if tender.engine.map is None:
            pen = tender.loader.invoke("pen")
            map = self.make_map(2, pen)
            tender.engine.change_map(map)
            map.place(tender.hero)

        try:
            self.play()
        except Quitting:
            self.save_game()
            print(f"See you later, brave {tender.hero.name}...")
            
    def play(self):
        """ Main game loop. 
        
        return True if the hero is still alive, False otherwise. 
        """
        done = False
        while not done:
            if tender.hero.is_dead:
                return False

            for actor in tender.engine.all_actors():
                if actor.has_played or actor.is_dead:
                    continue
                if actor is tender.hero:
                    while not tender.hero.has_played:
                        print(tender.engine.map.to_text())
                        move = tender.ui.read_next_move()
                        if isinstance(move, (StatusEvent, Events)):
                            if move:
                                print(move)
                                actor.set_played()
                elif actor in tender.engine.map:
                    event = actor.act()
                    if event:
                        print(event)
                if tender.hero.is_dead:
                    self.del_game()
                    return False

            if tender.hero.has_played:
                events = tender.engine.advance_turn()
                print(events or "no turn updates")
        return True
    
    def create_hero(self):
        """ Prompt the user on what their character should be like. """
        print("Character creation is really easy since all the stats are "
              "either random or abitrary. However, you get to chose the "
              "name of your character.")
        name = input("Name: ")
        tender.hero = tender.loader.invoke("novice")
        tender.hero.name = name
        self.condenser.save("hero", tender.hero)

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

            # TODO: return a Move event instead
            tender.hero.set_played()
            return True

        else:
            print(f"there are no stairs at {pos}")
            return None
        
        
    def shutdown(self):
        """ Gracefully shutdown after saving everything. """
        ...
        
