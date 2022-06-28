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

""" Registry for commands that can be called from various parts of the game. """

import inspect
import functools

from .tags import Tag
from .geometry import vect
from .weapons import Weapon
from . import tender

# all the methods we do not want to auto register
_NO_AUTO_REG = set()


def no_auto_reg(funct):
    """ Decorator to mark a callable as not exported as an CommandMap command. """
    if hasattr(funct, "__qualname__"):
        _NO_AUTO_REG.add(funct.__qualname__)
    return funct


class CommandMap:
    """ Mapping between command names and functions 
    
    command functions can be explicitly registered or be implicitly defined as instance 
    methods of CommandMap or one of it's subclasses.
    
    command functions will receive "engine" and "ui" as their first two parameters if 
    they declare them in their signature.
    """

    def __init__(self, name, prefix=None):
        """ 
        name: for documentation purpose only
        prefix: all command lookups must include this prefix, useful to avoid clashes 
                between multiple sub-maps. Ex.: if prefix='foo-', then accessing `bar()` 
                is done with `commands["foo-bar"]()`
        """
        
        self._commands = {}
        self._sub_maps = []
        self.name = name
        self.prefix = prefix
    
    def __contains__(self, command):
        return command in self._commands or hasattr(self, command)

    @no_auto_reg
    def register(self, funct, name=None):
        # discover the name if not provided
        if name is None:
            if not hasattr(funct, "__name__") or "lambda" in funct.__name__:
                raise ValueError("Can't register function: name not provided "
                                 "and funct is not a named function.")
            name = funct.__name__.replace("_", "-")
        self._commands[name] = funct
        
    @no_auto_reg
    def register_sub_map(self, sub_map):
        self._sub_maps.append(sub_map)

    def _format_entry(self, name, funct):
        if self.prefix:
            name = self.prefix + name
        name = name.replace("_", "-")
        if hasattr(funct, "__doc__") and funct.__doc__ is not None:
            return f"- {name}: {funct.__doc__.strip()!r}"
        else:
            return f"- {name}"
        
    @no_auto_reg
    def summary(self):
        """ Return a string that summarized which commands are available in this 
        CommandMap and all it's sub-maps. """
        entries = []
        
        lines = [f"Content of {self.__class__.__name__}(name={self.name!r}):"]
        for name, funct in self._commands.items():
            entries.append(self._format_entry(name, funct))
        for name, value in inspect.getmembers(self):
            if name.startswith("_"):
                continue
            if callable(value) and not self._do_not_reg(value):
                entries.append(self._format_entry(name, value))
        lines += sorted(entries)
        for sub in self._sub_maps:
            lines.append(sub.summary())
        return "\n".join(lines)
        
    def _do_not_reg(self, funct):
        return hasattr(funct, "__qualname__") and funct.__qualname__ in _NO_AUTO_REG
        
    def _apply_global_args(self, funct):
        """ 
        Return a function with partial binding of arguments that we already know about 
        and do not receive from the caller when the command is later called.
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

    def _get_command(self, command):
        if isinstance(command, Tag):
            command = command.name
        if self.prefix:
            if not command.startswith(self.prefix):
                return None
            command = command.replace(self.prefix, "", 1)
            
        funct = None
        if command in self._commands:
            funct = self._commands[command]
        elif hasattr(self, command):
            funct = getattr(self, command)
        elif hasattr(self, command.replace("-", "_")):  
            # FIXME: redoing the replace() is very ugly
            funct = getattr(self, command.replace("-", "_"))
        return funct

    def __getitem__(self, command):
        """ Retrun a callable for given command.
        Globals are partially applied to the callable. 
        
        `command` can be an CommandTag or a string.
        """
        funct = self._get_command(command)
        if self._do_not_reg(funct):
            funct = None
        if funct is None:
            for sub_map in self._sub_maps:
                funct = sub_map._get_command(command)
                if funct is not None:
                    break
                 
        if funct is None:
            raise ValueError(f"command {command} is not registered or defined "
                             "as a method.")
        return self._apply_global_args(funct)

    @no_auto_reg
    def call(self, command, *args):
        funct = self[command]
        return funct(*args)


class CoreCommands(CommandMap):
    """ Main commands that are used in multiple game contexts """
    def __init__(self, name="Core commands", prefix=None):
        super().__init__(name, prefix)

    # TODO: move this to UIcommands
    def prompt(self, *options):
        """ Prompt the player to make a choice. """
        return tender.ui.prompt(*options)
    
    # TODO: move this to UIcommands    
    def yes_no_prompt(self):
        return self.promp("Yes", "No")
        
    def log(self, *args):
        print(f"Dialogue command called with args: {args}")
        
    def move_or_act(self, direction):
        """ Perform the default command in direction (a vector). """
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

    def pickup_item(self):
        """ Take the first item on top of the loot pile where we are. """
        pos = tender.engine.map.find(tender.hero)
        stack = tender.engine.map.items_at(pos)
        if stack:
            return tender.hero.pickup()
        else:
            print(f"there is nothing to pickup at {pos}")
            return None

    def equip_item(self, item, *args):
        """ Wield a weapon, or don a piece of armor. """
        if isinstance(item, Weapon):
            tender.hero.weapon = item
        else:
            raise ValueError(f"Can't equip {item.__class__}")
