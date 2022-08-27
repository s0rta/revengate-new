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
import pickle
from logging import debug

from . import tender
from .randutils import rng
from .loader import DATA_DIR, TopLevelLoader, data_path
from .engine import Engine
from .ui import TextUI, Quitting, KivyUI
from .commands import CommandMap, CoreCommands
from .maps import Connector, Builder, Map, BiasedRecursiveBacktracker
from .area import Area
from .events import is_action, StairsEvent, Events
from .factions import Mood, Faction
from .tags import t, ConvoTopic
from .messages import MessageStore

from .graphics import RevengateApp


CORE_FILE = "core.tml"
# Reasonable Linux defaults, but ideally we get a more cross platform value from Kivy 
# after initializing the App.
CONFIG_ROOT = os.environ.get("XDG_CONFIG_HOME", "~/.config")
CONFIG_DIR = os.path.join(CONFIG_ROOT, "revengate")

# all the file keys you need to get a complete saved game
SAVED_GAME_KEYS = ["hero", "engine", "mapid", "dungeon", "messages"]

ALL_MONSTERS = ["sentry-scarab", "giant-locust", "plasus-rat", "sulant-tiger", 
                "sahwakoon", "labras", "cave-cat", "sewer-otter", "trinian-bat",
                "pacherr", "pacherr-matriarch", "eguis", "centipede",
                "slime", "rat", "wolf"]


class Condenser:
    """ Save and reload game objects """

    def __init__(self, data_dir=CONFIG_DIR):
        """data_dir: the top-level directory for per-player files like saved games. 
        if None, a Linux-specific default is used. """
        self.data_dir = os.path.expanduser(data_dir)

    def file_path(self, key):
        fname = f"{key}.pickle"
        return os.path.join(self.data_dir, "save", fname)
        
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

    def has_file(self, key):
        fpath = self.file_path(key)
        return os.path.isfile(fpath)
    
    def has_saved_game(self):
        return all(map(self.has_file, SAVED_GAME_KEYS))

    def delete_game(self):
        for key in SAVED_GAME_KEYS:
            self.delete(key)


class GameMgmtCommands(CommandMap):
    def __init__(self, condenser, name="Game Management"):
        super().__init__(name)
        self.condenser = condenser
        self.register(self.condenser.delete_game)
        self.register(self.condenser.has_saved_game)

    def is_tender_ready(self):
        """ Return whether all parts of the tender have been initialized. """
        parts = set(SAVED_GAME_KEYS) - {"mapid"} 
        parts |= {"ui", "loader", "commands"}
        for part in parts:
            if getattr(tender, part) is None:
                return False
        return True

    def save_game(self):
        """ Save an ongoing game to disk. """
        self.condenser.save("engine", tender.engine)
        self.condenser.save("hero", tender.hero)
        self.condenser.save("mapid", tender.engine.map.id)
        self.condenser.save("dungeon", tender.dungeon)
        self.condenser.save("messages", tender.messages)
        
    def restore_game(self):
        """ Load a saved game from disk. """
        tender.hero = self.condenser.load("hero")
        tender.engine = self.condenser.load("engine")
        tender.dungeon = self.condenser.load("dungeon")
        tender.messages = self.condenser.load("messages")
        mapid = self.condenser.load("mapid")
        
        if mapid is not None and tender.engine is not None:
            tender.engine.change_map(tender.dungeon[mapid])

    def purge_game(self):
        """ Get rid of a game, both from disk and from in-memory state. """
        self.condenser.delete_game()
        tender.dungeon = None
        tender.hero = None
        tender.engine = None
        tender.messages = None


class Governor:
    def __init__(self, wizard_mode=False, new_game=False, **kwargs):
        self.factions = []
        self.new_game = new_game

        tender.loader = TopLevelLoader()
        tender.loader.load(open(data_path(CORE_FILE), "rt"))
        tender.sentiments = tender.loader.get_instance("core_sentiments")
        
        tender.commands = CoreCommands(name="core-actions")
        tender.commands.register(self.follow_stairs)
        tender.commands.register(self.new_game_response)
        tender.commands.register(self.npc_turn)
        
        tender.ui = KivyUI()
        self.app = RevengateApp(wizard_mode)

        self.condenser = Condenser(self.app.user_data_dir)
        tender.commands.register_sub_map(GameMgmtCommands(self.condenser))
        self.init_factions()
    
    def make_map(self, nb_monsters, item, from_pos=None, parent_map=None):
        lvl = len(tender.dungeon.maps) + 1

        map = Map()
        builder = Builder(map)
        builder.init(80, 25)
        if lvl < 3:
            builder.gen_level()

            # FIXME: vibe gen centers on rooms and does not work on pure mazes
            nb_passes = 3  # very arbitrary, should be tuned during play testing
            pairs = zip(rng.choices(list(builder.iter_rooms()), k=nb_passes), 
                        rng.choices(self.factions, k=nb_passes))
            for room, fact in pairs:
                builder.add_vibe(room, fact)

        elif lvl < 5:
            # traboules
            algo = BiasedRecursiveBacktracker(builder, rect=None, 
                                              reconnect_prob=0.1,
                                              straight_line_bias=5)
            builder.maze_fill(algo)  
        else:
            # catacombs
            algo = BiasedRecursiveBacktracker(builder, rect=None, 
                                              reconnect_prob=0.05,
                                              straight_line_bias=.2)
            builder.maze_fill(algo)  
        
        # stairs
        if lvl < 5:
            # after 5 levels, we can't go down anymore
            if lvl < 3:
                pos = None
            else:
                pos = map.random_pos(free=True)
            builder.staircase(pos=pos)
        else:
            # omadar has something to tell us on the last level
            omandar = tender.loader.invoke("observer", name="Omandar")
            omandar.next_dialogue = t("deepest_level")
            map.place(omandar)

        if parent_map:
            if lvl < 3:
                pos = None
            else:
                pos = map.random_pos(free=True)
            builder.staircase(pos, "<", from_pos, parent_map)

        for name in rng.choices(ALL_MONSTERS, k=nb_monsters):
            a = tender.loader.invoke(name)
            map.place(a)
        map.place(item)
        tender.dungeon.add_map(map, parent_map)
        return map

    def make_first_map(self):
        pen = tender.loader.invoke("pen")
        map = self.make_map(3, pen)
        
        obs = tender.loader.invoke("observer")
        obs.next_dialogue = t("first_level")
        map.place(obs)

        for i in range(5):
            rat = tender.loader.invoke("rat")
            map.place(rat)

        #rob = tender.loader.invoke("rob", rank="landlord")
        #map.place(rob)

        tender.engine.change_map(map)
        if tender.hero:
            map.place(tender.hero)
        return map

    def start(self):
        """ Start a game. """
        if self.new_game:
            tender.commands["purge_game"]()
            self.new_game_response("Baw")
        self.app.run()
            
    def npc_turn(self, *args):
        """ Let all non-player actors do their turn, return return the events from their 
        actions.
        
        This function is no-op if actors have already played and the turn has not been 
        advanced on the engine.
        """
        # TODO: this could easily be moved to the Engine if we generalize the concept of 
        # hero. Currently, the engine does not give any actor a preferential treatment.
        events = Events()
        for actor in tender.engine.all_actors():
            if actor.has_played or actor.is_dead:
                continue
            if actor is tender.hero and not tender.hero.has_played:
                # hero's moves are automated if it has a strategy, player directed 
                # otherwise
                actor.update_strategies()
                strat = actor.strategy
                if strat:
                    events += actor.act(False)
                else:
                    # early return forces the UI to prompt for action
                    return events
            elif actor in tender.engine.map and not actor.has_played:
                events += actor.act()
            if tender.hero.is_dead:
                return events
        # If we made it this far, everyone got a chance to act during this turn.
        tender.engine.turn_complete = True
        debug(f"Turn {tender.engine.current_turn}: done with combat")
        return events

    def hero_turn(self):
        # not used anymore, only kept to illustrate how self.play() works
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
        # This game loop is obsolete, but it's useful for showing what the event-based 
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

    def init_factions(self):
        # beasts
        beasts = Faction("Beasts", "beasts")
        beasts.add_mood("mouse droppings")
        beasts.add_mood("scratches on the floor")
        beasts.add_mood("half eaten old animal corpse")
        self.factions.append(beasts)
        # lumiere
        # neutral
        # canut
        # smugglers
        smugglers = Faction("Smugglers", "smugglers")
        smugglers.add_mood("*dagger", weight=1/10)
        smugglers.add_mood("*saber", weight=1/20)
        smugglers.add_mood("*old_map", weight=1/15)
        smugglers.add_mood("old tobacco smell")
        smugglers.add_mood("cigar stubs on the ground")
        smugglers.add_mood("fragments of broken pottery")
        smugglers.add_mood("dirty terracotta pot", weight=1/30)

        self.factions.append(smugglers)

    def new_game_response(self, hero_name):
        self.condenser.delete_game()
        tender.dungeon = Area()

        tender.hero = tender.loader.invoke("novice", name=hero_name)
        tender.engine = Engine()
        tender.messages = MessageStore()

        map = self.make_first_map()
        tender.dungeon.add_map(map, parent=None)
        tender.commands["save-game"]()
        
    def follow_stairs(self):
        from_pos = tender.engine.map.find(tender.hero)
        tile = tender.engine.map[from_pos]
        if isinstance(tile, Connector):
            print(f"following stairs at {from_pos}")
            mapid = tile.dest_map
            if mapid is None:
                sword = tender.loader.invoke("sword")
                map = self.make_map(5, sword, from_pos, tender.engine.map)
                
            else:
                map = tender.dungeon[mapid]
            # switch the map
            next_pos = map.arrival_pos(tender.engine.map.id)
            tender.engine.map.remove(tender.hero)
            tender.engine.change_map(map)
            map.place(tender.hero, next_pos, fallback=True)

            tender.hero.set_played()
            return StairsEvent(tender.hero, from_pos)
        else:
            print(f"there are no stairs at {from_pos}")
            return None
        
    def shutdown(self):
        """ Gracefully shutdown after saving everything. """
        ...
