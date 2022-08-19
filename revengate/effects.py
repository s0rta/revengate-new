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

""" Effects (immediate or over time) carried by items and weapons. """

from .tags import TagSlot
from .combat_defs import RES_FACTOR, Family
from .randutils import rng
from .strategies import Paralyzed


class Effect:
    """ A long term effect. """
    family = TagSlot(Family)

    def __init__(self, name, h_delta=0, family=None, duration=None,
                 verb=None, attribute_deltas=None, 
                 permanent=False):
        if duration is not None and permanent:
            raise ValueError("Permanent effects can't have a duration.")
        self.name = name
        self.duration = duration  # either an int or a (min, max) tuple 
        self.h_delta = h_delta
        self.family = family
        self.verb = verb
        self.prob = 1.0  # probability that the effect will happen
        self.attribute_deltas = attribute_deltas or {}  # attrname -> delta as int
        self.permanent = permanent

    def _get_damage(self):
        """ For weapons, it's easier to think in terms of damage. """
        return -self.h_delta
    
    def _set_damage(self, dmg):
        self.h_delta = -dmg
    damage = property(_get_damage, _set_damage)

    def apply(self, actor, start_turn):
        if self.permanent:
            for attr, delta in self.attribute_deltas.items():
                val = getattr(actor, f"_{attr}") + delta
                setattr(actor, attr, val)
                
    def materialize(self, start_turn, resistances):
        """ Turn the effect into something concrete that changes the receiving actor: a 
        Condition or a transient Strategy.
        
        The actor is responsible for integrating the materialization and to remove it 
        once it's expired.
        """
        cond_delta = self.h_delta
        if self.family in resistances:
            cond_delta *= RES_FACTOR
        if isinstance(self.duration, int):
            stop = start_turn + self.duration
        else:
            stop = start_turn + rng.randint(*self.duration)
        return Condition(self, start_turn, stop, cond_delta, self.attribute_deltas)


class Analysis(Effect):
    def __init__(self, name, h_delta=0, family=None, duration=None, verb=None):
        attribute_deltas = {"perception": 60}
        super().__init__(name, h_delta, family, duration, verb, attribute_deltas)


class Paralysis(Effect):
    def materialize(self, start_turn, resistances):
        strat = Paralyzed(self.name)
        strat.ttl = self.duration  # TODO: Check if it's +1 or not
        return strat


class Condition(object):
    """ The materialization of an effect. 
    
    If an effect is successfully applied to someone, they carry the condition. 
    """

    def __init__(self, effect, start, stop, h_delta=0, attribute_deltas=None):
        super(Condition, self).__init__()
        self.effect = effect
        self.start = start
        self.stop = stop
        self.h_delta = h_delta  # per-turn health delta
        self.attribute_deltas = attribute_deltas or {}  # attrname -> delta as int
    
    def attribute_delta(self, attr_name):
        """ Return the attribute deltas for the given attribute name. """
        return self.attribute_deltas.get(attr_name, None)
        
    def is_expired(self, current_turn):
        return current_turn > self.stop

    def is_active(self, current_turn):
        return self.start <= current_turn <= self.stop


class EffectVector:
    """ Something that changes health and that is directed at an actor. """
    family = TagSlot(Family)
    
    def __init__(self, name, h_delta=0, family=None, verb=None):
        super().__init__()
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


class Injurious(EffectVector):
    """ Something that can hurt someone or something.  This could be a tool,
    a body part, a spell, or a toxin. """

    def __init__(self, name, damage=0, family=None, verb=None):
        super().__init__(name, -damage, family, verb)
