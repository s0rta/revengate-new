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

import inspect
import functools

from .tags import Tag
from .geometry import vect
from .dialogue import Action
from .events import Pickup
from . import tender, CREDITS


class ActionMap:
    """ Mapping between action names and functions 
    
    Action funtions can be explicitely registered or be implicitely defined as instance 
    methods of ActionMap or one of it's subclasses.
    
    Actions functions will receive "engine" and "ui" as their first two paramers if they 
    declare them in their signature.
    """

    def __init__(self):
        self._actions = {}
    
    def __contains__(self, action):
        return action in self._actions or hasattr(self, action)
        
    def register(self, funct, name=None):
        # discover the name if not provided
        if name is None:
            if not hasattr(funct, "__name__") or "lambda" in funct.__name__:
                raise ValueError("Can't register function: name not provided "
                                 "and funct is not a named function.")
            name = funct.__name__
        self._actions[name] = funct
        
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

    def __getitem__(self, action):
        """ Retrun a callable for given action.
        Globals are partially applied to the callable. 
        
        `action` can be an ActionTag or a string.
        """
        if isinstance(action, Tag):
            action = action.name
        if action in self._actions:
            funct = self._actions[action]
        elif hasattr(self, action):
            funct = getattr(self, action)
        else:
            raise ValueError(f"Action {action} is not registered or defined "
                             "as a class method.")
        return self._apply_global_args(funct)

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
        new_pos = direction + cur_pos
        if map.is_free(new_pos):
            res = tender.hero.move(new_pos)
        else: 
            other = map.actor_at(new_pos)
            if other is not None:
                # TODO: prompt the player before attacking a friend
                res = tender.hero.attack(other)
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

    def pickup_item(self):
        pos = tender.engine.map.find(tender.hero)
        stack = tender.engine.map.items_at(pos)
        if stack:
            item = stack.top()
            tender.hero.inventory.append(item)
            tender.engine.map.remove(item)
            return Pickup(tender.hero, item)
        else:
            print(f"there is nothing to pickup at {pos}")
            return None
        
