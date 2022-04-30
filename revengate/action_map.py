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

import inspect
import functools
from pprint import pprint

from .tags import Tag
from .geometry import vect
from .dialogue import Action
from .events import Pickup
from . import tender, CREDITS

# all the methods we do not want to auto register
_NO_AUTO_REG = set()


def no_auto_reg(funct):
    """ Decorator to mark a callable as not exported as an ActionMap action. """
    if hasattr(funct, "__qualname__"):
        _NO_AUTO_REG.add(funct.__qualname__)
    return funct


class ActionMap:
    """ Mapping between action names and functions 
    
    Action funtions can be explicitely registered or be implicitely defined as instance 
    methods of ActionMap or one of it's subclasses.
    
    Actions functions will receive "engine" and "ui" as their first two paramers if they 
    declare them in their signature.
    """

    def __init__(self, name):
        self._actions = {}
        self._sub_maps = []
        self.name = name
    
    def __contains__(self, action):
        return action in self._actions or hasattr(self, action)

    @no_auto_reg
    def register(self, funct, name=None):
        # discover the name if not provided
        if name is None:
            if not hasattr(funct, "__name__") or "lambda" in funct.__name__:
                raise ValueError("Can't register function: name not provided "
                                 "and funct is not a named function.")
            name = funct.__name__.replace("_", "-")
        self._actions[name] = funct
        
    @no_auto_reg
    def register_sub_map(self, sub_map):
        self._sub_maps.append(sub_map)

    def _format_dump_entry(self, name, funct):
        if hasattr(funct, "__doc__") and funct.__doc__ is not None:
            return f"{name}: {funct.__doc__!r}"
        else:
            return name
        
    @no_auto_reg
    def dump(self):
        entries = []
        print(f"Dumping the content of ActionMap(name={self.name!r})")
        for name, funct in self._actions.items():
            entries.append(self._format_dump_entry(name, funct))
        for name, value in inspect.getmembers(self):
            if name.startswith("_"):
                continue
            if callable(value) and not self._do_not_reg(value):
                entries.append(self._format_dump_entry(name, value))
        for name in sorted(entries):
            print(f"- {name}")
        for sub in self._sub_maps:
            sub.dump()
        
    def _do_not_reg(self, funct):
        return hasattr(funct, "__qualname__") and funct.__qualname__ in _NO_AUTO_REG
        
    def _apply_global_args(self, funct):
        """ 
        Return a function with partial binding of arguments that we already know about 
        and do not receive from the caller when the action is later called.
        """
        sig = inspect.signature(funct)
        params = sig.parameters
        kwargs = {}
        for key in ["engine", "ui"]:
            if key in params:
                kwargs[key] = getattr(tender, key)
        if kwargs:
            funct = functools.partial(funct, **kwargs)
        return funct

    def _get_action(self, action, strict=True):
        if isinstance(action, Tag):
            action = action.name
            
        funct = None
        if action in self._actions:
            funct = self._actions[action]
        elif hasattr(self, action):
            funct = getattr(self, action)
        elif hasattr(self, action.replace("-", "_")):  
            # FIXME: redoing the replace() is very ugly
            funct = getattr(self, action.replace("-", "_"))
        elif strict:            
            raise ValueError(f"Action {action} is not registered or defined "
                             "as a class method.")
        return funct

    def __getitem__(self, action):
        """ Retrun a callable for given action.
        Globals are partially applied to the callable. 
        
        `action` can be an ActionTag or a string.
        """
        funct = self._get_action(action, strict=False)
        if self._do_not_reg(funct):
            funct = None
        if funct is None:
            for sub_map in self._sub_maps:
                funct = sub_map._get_action(action, strict=False)
                if funct is not None:
                    break
                 
        if funct is None:
            raise ValueError(f"Action {action} is not registered or defined "
                             "as a class method.")
        return self._apply_global_args(funct)

    @no_auto_reg
    def call(self, action, *args):
        funct = self[action]
        return funct(*args)

    def prompt(self, *options):
        """ Prompt the player to make a choice. """
        return tender.ui.prompt(*options)
    
    def yes_no_prompt(self):
        return self.promp("Yes", "No")
    
    def show_credits(self):
        tender.ui.show_text(CREDITS)
    
    def log(self, *args):
        print(f"Dialogue action called with args: {args}")
        
    def move_or_act(self, direction):
        res = None
        map = tender.engine.map
        cur_pos = map.find(tender.hero)
        new_pos = tuple(direction + cur_pos)
        other = map.actor_at(new_pos)

        if map.is_free(new_pos):
            res = tender.hero.move(new_pos)
        elif other is not None:
            if tender.hero.hates(other):
                res = tender.hero.attack(other)
            else:
                res = tender.hero.talk(other)
                if not res:
                    print(f"{other} is in the way!")
        else:
            print(f"there is already something at {new_pos}")
        if res:
            tender.hero.set_played()
        return res
        
    def move_or_act_up(self):
        return self.move_or_act(vect(0, 1))
    
    def move_or_act_down(self):
        return self.move_or_act(vect(0, -1))

    def move_or_act_right(self):
        return self.move_or_act(vect(1, 0))

    def move_or_act_left(self):
        return self.move_or_act(vect(-1, 0))

        
class SimpleMap(ActionMap):
    def pickup_item(self):
        pos = tender.engine.map.find(tender.hero)
        stack = tender.engine.map.items_at(pos)
        if stack:
            return tender.hero.pickup()
        else:
            print(f"there is nothing to pickup at {pos}")
            return None
