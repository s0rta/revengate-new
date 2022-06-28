# Copyright © 2020–2022 Yannick Gingras <ygingras@ygingras.net> and contributors

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


from .tags import Tag, TagSlot
from .items import Item


class Family(Tag):
    pass 


class Families:
    IMPACT = Family("impact")
    SLICE  = Family("slice")
    PIERCE = Family("pierce")
    ARCANE = Family("arcane")
    HEAT   = Family("heat")
    ACID   = Family("acid")
    POISON = Family("poison")


class Effect:
    """ A long term effect. """
    family = TagSlot(Family)

    def __init__(self, name, duration, h_delta, family, verb=None):
        self.name = name
        self.duration = duration  # either an int or a (min, max) tuple 
        self.h_delta = h_delta
        self.family = family
        self.verb = verb
        self.prob = 1.0  # probability that the effect will happen

    def _get_damage(self):
        """ For weapons, it's easier to think in terms of damage. """
        return -self.h_delta

    def _set_damage(self, dmg):
        self.h_delta = -dmg
        
    damage = property(_get_damage, _set_damage)


class Condition(object):
    """ The materialization of an effect. 
    
    If an effect is successfully appied to someone, they carry the condition. 
    """

    def __init__(self, effect, start, stop, h_delta):
        super(Condition, self).__init__()
        self.effect = effect
        self.start = start
        self.stop = stop
        self.h_delta = h_delta  # per-turn health delta 


class HealthVector:
    """ Something that changes health and that is directed at an actor. """
    family = TagSlot(Family)
    
    def __init__(self, name, h_delta, family, verb=None):
        super(HealthVector, self).__init__()
        self.name = name
        self.h_delta = h_delta
        self.family = family
        self.verb = verb
        self.effects = []  # long term effects of applying the vector
        self.hit_sound = None  # any sound file that the UI can handle
        
    def __str__(self):
        return self.name

    def _get_damage(self):
        """ For weapons, it's easier to think in terms of damage. """
        return -self.h_delta
    
    def _set_damage(self, dmg):
        self.h_delta = -dmg
    damage = property(_get_damage, _set_damage)


class Injurious(HealthVector):
    """ Something that can hurt someone or something.  This could be a tool,
    a body part, a spell, or a toxin. """

    def __init__(self, name, damage, family, verb=None):
        super().__init__(name, -damage, family, verb)


class Weapon(Item, Injurious):
    """ An actual weapon.  Something that takes inventory space and must be 
    weilded. """

    def __init__(self, name, damage, family, weight, char='⚔️', verb=None):
        Item.__init__(self, name, weight, char)
        Injurious.__init__(self, name, damage, family, verb)

    def __str__(self):
        return self.name


class Spell(HealthVector):
    """ A magical invocation """

    def __init__(self, name, h_delta, family, cost, verb=None):
        super(Spell, self).__init__(name, h_delta, family, verb)
        self.cost = cost
        
