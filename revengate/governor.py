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

from . import tender
from .randutils import rng
from .loader import DATA_DIR, TopLevelLoader, data_path
from .engine import Engine
from .ui import TextUI
from .action_map import ActionMap
from .maps import Map, Builder
from .events import StatusEvent, Events

CONFIG_DIR = "~/.config/revengate"
HERO_FILE = "hero.toml"
CORE_FILE = "core.toml"

# TODO: where does the UI come from?

class Governor:
    def __init__(self):
        # find where all the files are, which changes a lot depending on the OS
        self.config_dir = os.path.expanduser(CONFIG_DIR)
        self.loader = TopLevelLoader()
        tender.engine = Engine(self.loader)
        # TODO: get rid of this circular dep by letting everyone reference the engine 
        # lazily from the tender module.
        self.loader.engine = tender.engine 
        
        tender.ui = TextUI()
        tender.action_map = ActionMap()

    def init_map(self):
        map = Map()
        builder = Builder(map)
        builder.init(60, 20)
        builder.room((5, 5), (20, 15), True)
        builder.room((12, 7), (13, 12), True)
        tender.engine.change_map(map)

        sword = self.loader.invoke("sword")
        map.place(sword)
        
        for name in rng.choices(["rat", "wolf"], k=3):
            a = self.loader.invoke(name)
            map.place(a)
    
    def start(self):
        """ Start a game. """
        self.loader.load(open(data_path(CORE_FILE), "rt"))
        # see if there is a hero file, create a new character otherwise
        self.create_hero()
        
        # pre-game naration
        dia = self.loader.get_instance("intro")
        tender.ui.show_dia(dia)
        # play!
        self.init_map()
        tender.engine.map.place(tender.hero)
        self.play()
    
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
                else:
                    event = actor.act()
                    if event:
                        print(event)
                if tender.hero.is_dead:
                    return False

            if tender.hero.has_played:
                events = tender.engine.advance_turn()
                print(events or "no turn updates")
            # done = True

        #while len([f for f in factions if len(factions[f]) > 0]) > 1:
            #print(eng.advance_turn() or "no turn updates")
            #filter_empties()
            #for a in actors:
                #if a.health <= 0:
                    #continue
                #event = a.act(map)
                #if event:
                    #print(event)
            #filter_empties()
            #print(map.to_text())
        return True
    
    def create_hero(self):
        """ Prompt the user on what their character should be like. """
        print("Character creation is really easy since all the stats are "
              "either random or abitrary. However, you get to chose the "
              "name of your character.")
        name = input("Name: ")
        tender.hero = self.loader.invoke("novice")
        tender.hero.name = name
    
    def shutdown(self):
        """ Gracefully shutdown after saving everything. """
        ...
        
