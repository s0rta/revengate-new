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

class DmgType(enum.Enum):
    """ Types of damages that weapons can inflict. """
    IMPACT = enum.auto()
    SLICE  = enum.auto()
    PIERCE = enum.auto()
    ARCANE = enum.auto()
    HEAT   = enum.auto()


class Hit(object):
    """ A successful hit with a weapon.
    
    This is mostly to keep track of what happened so we can show it to the 
    player. """
    def __init__(self, attacker, victim, weapon, damage, critical):
        super(Hit, self).__init__()
        self.attacker = attacker
        self.victim = victim
        self.weapon = weapon
        self.damage = damage
        self.critical = critical
        
    def __str__(self):
        s = (f"{self.attacker} hit {self.victim} with a {self.weapon}"
             f" for {self.damage} damages!")
        if self.critical:
            s += " Critical hit!"
        return s

class Hits(list):
    """ A group of hits.  Misses are implicitely ignored. """
    def __init__(self, *hits):
        if hits:
            hits = filter(bool, hits)
            super(Hits, self).__init__(hits)
        else:
            super(Hits, self).__init__()
        
    def __str__(self):
        return " ".join(map(str, self))
        
    def add(self, hit):
        if hit:
            self.append(hit)


class Injurious(object):
    """ Something that can hurt someone or something.  This could be a tool,
    a body part, a spell, or a toxin. """
    def __init__(self, name, damage, dmg_type, verb=None):
        super(Injurious, self).__init__()
        self.name = name
        self.damage = damages
        self.dmg_type = dmg_type
        self.verb = verb
        
    def __str__(self):
        return self.name


class Weapon(Injurious):
    """ An actual weapon.  Something that takes inventory space and must be 
    weilded. """
    def __init__(self, name, damage, dmg_type, verb=None):
        super(Weapon, self).__init__(name, damage, dmg_type, verb=None)
