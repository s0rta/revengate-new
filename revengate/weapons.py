# Copyright © 2020 Yannick Gingras <ygingras@ygingras.net>

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

""" Weapons logic and common weapon types. """

import enum
from .tags import Tag

class DmgType(Tag):
    pass

class DmgTypes:
    IMPACT = DmgType("impact")
    SLICE  = DmgType("slice")
    PIERCE = DmgType("pierce")
    ARCANE = DmgType("arcane")
    HEAT   = DmgType("heat")


class StatusEvent(object):
    """ Something that changes the status of an actor. 
    
    This is mostly to keep track of what happened so we can show it to the 
    player. 
    
    Any function that could return a StatusEvent can also return None if the 
    event didn't occur. 
    """
    def __init__(self, target):
        super(StatusEvent, self).__init__()
        self.target = target

class HealthEvent(StatusEvent):
    """ The actor's health just got better or worse. """
    def __init__(self, target, h_delta):
        super(HealthEvent, self).__init__(target)
        self.h_delta = h_delta
        
    def __str__(self):
        if self.h_delta >= 0:
            return f"{self.target} heals {self.h_delta} points."
        else:
            return (f"{self.target} suffers {-self.h_delta} damages" 
                    " from injuries.")
                        
class Injury(HealthEvent):
    """ Something that hurts """
    def __init__(self, target, damage):
        super(Injury, self).__init__(target, -damage)

    @property
    def damage(self):
        return -self.h_delta
        

class Hit(Injury):
    """ A successful hit with a weapon. """
    def __init__(self, target, attacker, weapon, damage, critical=False):
        super(Hit, self).__init__(target, damage)
        self.attacker = attacker
        self.weapon = weapon
        self.critical = critical
        
    def __str__(self):
        s = (f"{self.attacker} hit {self.target} with a {self.weapon}"
             f" for {self.damage} damages!")
        if self.critical:
            s += " Critical hit!"
        return s

class Events(list):
    """ A group of StatusEvents.  None-events are implicitely ignored. """
    def __init__(self, *events):
        if events:
            events = filter(bool, events)
            super(Events, self).__init__(events)
        else:
            super(Events, self).__init__()
        
    def __str__(self):
        return " ".join(map(str, self))
       
    def __iadd__(self, other):
        other = filter(bool, other)
        return super(Events, self).__iadd__(other)
    
    def add(self, event):
        if event:
            self.append(event)


class Effect(object):
    """ A long term effect. """
    def __init__(self, name, duration, damage, dmg_type, verb=None):
        super(Effect, self).__init__()
        self.name = name
        self.duration = duration # either an int or a (min, max) tuple 
        self.damage = damage
        self.dmg_type = dmg_type
        self.verb = verb


class Condition(object):
    """ The materialization of an effect. """
    def __init__(self, effect, start, stop, h_delta):
        super(Condition, self).__init__()
        self.effect = effect
        self.start = start
        self.stop = stop
        self.h_delta = h_delta # per-turn health delta 


class Injurious(object):
    """ Something that can hurt someone or something.  This could be a tool,
    a body part, a spell, or a toxin. """
    def __init__(self, name, damage, dmg_type, verb=None):
        super(Injurious, self).__init__()
        self.name = name
        self.damage = damage
        self.dmg_type = dmg_type
        self.verb = verb
        self.effects = [] # long term effects of the injury
        
    def __str__(self):
        return self.name


class Weapon(Injurious):
    """ An actual weapon.  Something that takes inventory space and must be 
    weilded. """
    def __init__(self, name, damage, dmg_type, verb=None):
        super(Weapon, self).__init__(name, damage, dmg_type, verb=None)
