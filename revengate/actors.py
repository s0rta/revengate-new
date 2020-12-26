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

""" Actors are everyone moving and interacting with the world: beasts, 
monsters, characters, etc. 
"""

import random

from .tags import TagBag, TagSlot, Faction
from .strategies import StrategySlot
from .weapons import (Hit, Events, HealthEvent, Condition, Weapon, Spell, 
                      Families)

SIGMA = 12.5 # std. dev. for a normal distribution more or less contained in 0..100
MU = 50 # average of the above distribution
RES_FACTOR = 0.5 # 50% less damage if you have a resistance

class Actor(object):
    """ Base class of all actors. """
    # everyone defaults to 35% more damage with a critical hit
    critical_mult = 0.35 
    faction = TagSlot(Faction)
    strategy = StrategySlot()

    def __init__(self, health, armor, strength, agility):
        super(Actor, self).__init__()
        self.health = health
        self.armor = armor

        # main attributes
        self.strength = strength
        self.agility = agility

        self.resistances = TagBag('Family')
        self.weapon = None

        # taxon and identifiers
        self.species = None
        self.role = None
        self.rank = None
        self.name = None

        # turns logic
        self.initiative = random.random()
        self.engine = None
        self._last_update = None # last time we computed conditions and regen
        self.conditions = [] # mostly stuff that does damage over time

    def set_engine(self, engine):
        """ Finalize the registration with a game engine. """
        self.engine = engine
        self._last_update = engine.current_turn

    def update(self):
        """ 
        Do the update for all the turns since the last update.

        Return the summary of health changes.
        """
        # Actors are only update on the current level.  Upon revisiting a level, 
        # the updates for all missed turns are computed.
        if self.engine is None:
            raise RuntimeError("Actors must be registered with an engine before"
                               " performing turn updates.")
        events = Events()
        for t in range(self._last_update or 0, self.engine.current_turn + 1):
            events.add(self._update_one(t))
        return events
    
    def _update_one(self, turn):
        """
        Compute the effect of all over-time conditions for one turn.
        
        Return the summary of health changes.
        """
        events = Events()
        for cond in self.conditions:
            if cond.start <= turn <= cond.stop:
                self.health += cond.h_delta
                events.add(HealthEvent(self, cond.h_delta))
        self.conditions = [c for c in self.conditions if c.stop > turn]
        self._last_update = turn
        return events or None

    def __str__(self):
        if self.name:
            if self.rank:
                return f"{self.rank} {self.name}"
            return self.name
        if self.species:
            if self.rank or self.role:
                qual = self.rank or self.role
                return f"the {self.species} {qual}"
            return f"the {self.species}"
        if self.rank:
            return f"the {self.rank}"
        if self.role:
            return f"the {self.role}"
        order = self.__class__.__name__.lower()
        return f"the {order}"

    def attack(self, foe):
        """ Do all the stikes allowed in one turn against foe. """
        if self.weapon:
            return Events(self.strike(foe, self.weapon))
        else:
            return None

    def strike(self, foe, weapon):
        """ Try to hit foe, another actor, with weapon. 
        Automatically adjust foe's health when there is a hit. """
        crit = False

        # to-hit roll
        roll = random.normalvariate(MU, SIGMA)
        if roll < foe.get_evasion():
            return None  # miss!

        if roll > MU+2*SIGMA:
            # critical hit!
            crit = True
        h_delta = self.make_delta(weapon, crit)

        h_delta = foe.apply_delta(weapon, h_delta)
        return Hit(foe, self, weapon, -h_delta, crit)

    def apply_delta(self, vector, h_delta):
        """ 
        Receive damage or healing from a HealthVector.  Compute armor 
        protection, resistances, and weaknesses; update health; return how many 
        effective health points changed. 
        """
        # We don't resist healings
        if h_delta < 0:
            if vector.family in self.resistances:
                h_delta *= RES_FACTOR
            # spells bypass armor
            if not isinstance(vector, Spell):
                h_delta = min(0, h_delta + self.armor)
        h_delta = round(h_delta)
        self.health += h_delta

        # damage over time effects
        for effect in vector.effects:
            cond_delta = effect.h_delta
            if effect.family in self.resistances:
                cond_delta *= RES_FACTOR
            start = self.engine.current_turn + 1
            if isinstance(effect.duration, int):
                stop = start + effect.duration
            else:
                stop = start + random.randint(*effect.duration)
            cond = Condition(effect, start, stop, cond_delta)
            self.conditions.append(cond)
        return h_delta

    def get_evasion(self):
        # TODO: check for incapacitation
        return self.agility

    def make_delta(self, vector, critical=False):
        """ Return how much damage or healing the actor can do with a given 
        HealthVector taking into account procificency, incapacitation, and 
        critical hits. """

        # The relevant stat moves the 50% average.  Ex. if you are 60 strength, 
        # you hit 10% harder with weapons.
        if isinstance(vector, Weapon):
            stat = self.strength
        elif isinstance(vector, Spell):
            stat = self.intelligence
        else:
            stat = MU # everyone is perfectly average with improvised vectors

        if critical:
            h_delta = vector.h_delta * self.critical_mult
        else:
            h_delta = vector.h_delta

        return (1 + (stat - MU)/100.0) * h_delta * random.random()


class Monster(Actor):
    """ Monsters follow their instinct; they do not posses soffisticated 
    aspirations nor ethics. """
    def __init__(self, health, armor, strength, agility):
        super(Monster, self).__init__(health, armor, strength, agility)
        

class Character(Actor):
    """ Characters are everyone smart enough to become angry at something.  
    Most characters can use equipment.  Can be PC or NPC."""
    def __init__(self, health, armor, strength, agility, intelligence):
        super(Character, self).__init__(health, armor, strength, agility)
        self.intelligence = intelligence
        self.mana = round(intelligence / 3)
        self.spells = []
        
    def _find_spell(self, name):
        for spell in self.spells:
            if spell.name == name:
                return spell
        raise ValueError(f"No known spell called {name} for {self}")

    def cast(self, spell, target=None):
        """ Cast a spell, optionally directing it at target. """
        if isinstance(spell, str):
            spell = self._find_spell(spell)

        if self.mana < spell.cost:
            raise RuntimeError(f"Not enough mana to cast {spell.name}!")

        h_delta = self.make_delta(spell)
        h_delta = target.apply_delta(spell, h_delta)
        self.mana -= spell.cost
        return Hit(target, self, spell, -h_delta)


class Humanoid(Character):
    """ Your average human shapped creature. 
    Most creatures of that shape know how to throw a punch. """
    def __init__(self, health, armor, strength, agility, intelligence, fist_r=4, fist_l=None):
        super(Humanoid, self).__init__(health, armor, strength, agility, intelligence)
        if fist_r:
            self.fist_r = Weapon("fist", fist_r, Families.IMPACT)
        else:
            self.fist_r = None

        if fist_l:
            self.fist_l = Weapon("fist", fist_l, Families.IMPACT)
        else:
            self.fist_l = None
            
    def attack(self, foe):
        if self.weapon:
            return Events(self.strike(foe, self.weapon))
        else:
            hits = Events()
            if self.fist_r:
                hits.add(self.strike(foe, self.fist_r))
            if self.fist_l:
                hits.add(self.strike(foe, self.fist_l))
            return hits or None
