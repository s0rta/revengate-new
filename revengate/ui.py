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

import click
from pprint import pprint
from warnings import warn

from .tags import Tag
from .dialogue import Action
from . import tender

UP = '\x1b[A'
DOWN = '\x1b[B'
RIGHT = '\x1b[C'
LEFT = '\x1b[D'

TEXT_HELP = """UP, DOWN, RIGHT, LEFT: move or attack
q, ESC: quit
c: show credits
f: follow stairs
p: pickup an item from the ground
?: show help"""


class Quitting(Exception):
    pass


class UI:
    """ 
    Mock class for the general UI that should be designed in order to run the game on 
    both terminal and graphical interfaces.
    """

    def quit(self):
        # FIXME: there has to be a better way!
        raise Quitting("Giving up!")

    def show_dia(self, dia):
        raise NotImplementedError()
    
    def prompt(self, *options):
        raise NotImplementedError()

    def show_text(self, text):
        raise NotImplementedError()

    def show_turn_events(self, events):
        raise NotImplementedError()


class KivyUI(UI):
    def __init__(self, *args, **kwargs):
        # TODO: store the app or the root widget
        super().__init__(*args, **kwargs)

    def show_dia(self, dia):
        warn("Not fully implemented")
        pprint(dia)

    def prompt(self, *options):
        warn("Not fully implemented")
        pprint(options)
        choice = input("Make a choice: ")
        return choice

    def show_text(self, text):
        warn("Not fully implemented")
        print(text)

    def show_turn_events(self, events):
        warn("Not fully implemented")
        print(events)


class TextUI(UI):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.action_keys = {"?": self.show_help, 
                            "q": self.quit,
                            "c": "show_credits", 
                            "f": "follow-stairs",
                            "p": "pickup_item",
                            UP: "move_or_act_up",
                            DOWN: "move_or_act_down",
                            RIGHT: "move_or_act_right",
                            LEFT: "move_or_act_left"}
    
    
    def show_help(self):
        print(TEXT_HELP)

    def show_dia(self, dia):
        for part in dia.elems:
            # TODO: if this moves inside the ActionMap, UI doesn't need ActionMap
            if isinstance(part, Action):
                result = tender.action_map.call(part.name, *part.args)
                if part.after_ftag:
                    tender.action_map.call(part.after_ftag, result)
                    
            else:
                print(part)
                if part.after_ftag:
                    tender.action_map.call(part.after_ftag)
                input("Press ENTER to continue...")
            
    def prompt(self, *options):
        opt_map = dict(enumerate(options, 1))
        choice = None
        while choice not in opt_map:
            print("Choose one...")
            for num, text in opt_map.items():
                print(f"{num}: {text}")
            choice = input()
            if not choice or not choice.isdigit():
                choice = None
                print(f"Your response must be a number, not {choice!r}.")
            else:
                choice = int(choice)
                if choice not in opt_map:
                    print(f"{choice} is not a valid option.")
        if getattr(opt_map[choice], "after_ftag"):
            tender.action_map.call(opt_map[choice].after_ftag)
        return choice

    def read_next_move(self):
        c = click.getchar()
        directions = {UP: "up", DOWN: "down", RIGHT: "right", LEFT: "left"}
        if c in self.action_keys:
            action = self.action_keys[c]
            if callable(action):
                return action()
            else:
                return tender.action_map.call(action)
        else:
            print("invalid direction")

    def show_text(self, text):
        print(text)

    def show_turn_events(self, events):
        print(events)
