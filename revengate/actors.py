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

""" Actors are everyone moving and interacting with the world: beasts, 
monsters, characters, etc. 
"""

from operator import attrgetter
from uuid import uuid4

from .utils import best
from .randutils import rng
from .tags import TagBag, TagSlot, FactionTag
from .memory import Memory
from .weapons import Condition, Injurious, Weapon, Spell, Families
from .events import (Hit, Miss, Events, HealthEvent, Move, Rest, Death, is_action, 
                     Pickup, Conversation)
from .items import ItemsSlot
from . import tender


SIGMA = 12.5  # std. dev. for a normal distribution more or less contained in 0..100
MU = 50  # average of the above distribution
RES_FACTOR = 0.5  # 50% less damage if you have a resistance


class Actor(object):
    """ Base class of all actors. """
    # everyone defaults to 35% more damage with a critical hit
    critical_mult = 0.35 
    # how strong your sentiment has to be to move from neutral 
    sentiment_threshold = 0.75  
    faction = TagSlot(FactionTag)
    inventory = ItemsSlot()
    char = "X"  # How to render this actor on the text map

    def __init__(self, health, armor, strength, agility, perception=50):
        super().__init__()
        self.id = str(uuid4())
        self.health = health
        # It's possible to go above "full", used a reference point for perception.
        self.full_health = health
        self.armor = armor
        self.inventory = []
        self._strategies = []
        self.memory = Memory(self)

        # main attributes
        self.strength = strength
        self.agility = agility
        self.perception = perception
        self._perception_cache = {}  # value -> perceived_text

        self.resistances = TagBag('Family')
        self.weapon = None

        # taxon and identifiers
        self.species = None
        self.role = None
        self.rank = None
        self.name = None
        
        # lore and bestiary entry
        self.bestiary_img = None
        self.desc = ""

        # dialogues and conversations
        self.next_dialogue = None
        self.convo_topics = TagBag('ConvoTopic')

        # turns logic
        self.initiative = rng.random()
        self._last_action = None  # last turn when self made an action
        self._last_update = None  # last time we computed conditions and regen
        self.conditions = []  # mostly stuff that does damage over time

    def __hash__(self):
        return hash(self.id)

    @property
    def strategy(self):
        self._strategies = [strat for strat in self._strategies 
                            if not strat.is_expired()]
        key=attrgetter("priority")
        return best([strat for strat in self._strategies if strat.is_valid()], key)
        
    def _get_strategies(self):
        return self._strategies
        
    def _set_strategies(self, strategies):
        for strat in strategies:
            strat.assign(self)
        self._strategies = strategies
    strategies = property(_get_strategies, _set_strategies)
    
    @property
    def is_alive(self):
        return self.health > 0

    @property
    def is_dead(self):
        return self.health <= 0

    @property
    def has_played(self):
        if self._last_action is None:
            return False
        return self._last_action >= tender.engine.current_turn

    @property
    def last_action(self):
        """ Return the last turn when Actor made an action. 
        
        This property is read-only. 
        """
        return self._last_action
        
    def set_played(self):
        self._last_action = tender.engine.current_turn

    def update(self):
        """ 
        Do the update for all the turns since the last update.

        Return the summary of health changes.
        """
        # Actors are only updated on the current level.  Upon revisiting a level, 
        # the updates for all missed turns are computed.
        if tender.engine is None:
            raise RuntimeError("A global engine must be initialized before "
                               "performing turn updates.")
        events = Events()
        for t in range(self._last_update or 0, tender.engine.current_turn + 1):
            events += self._update_one(t)
        if self.health <= 0:
            events.add(self.die())
        return events
    
    def _update_one(self, turn):
        """
        Compute the effect of one over-time conditions for one turn.
        
        Return the summary of health changes.
        """
        events = Events()
        for cond in self.conditions:
            if cond.start <= turn <= cond.stop:
                self.health += cond.h_delta
                events.add(HealthEvent(self, cond.h_delta))
        self.conditions = [c for c in self.conditions if c.stop > turn]
        self._last_update = turn
        return events

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
    
    def status_str(self):
        # TODO: use perception
        if self.health > self.full_health * .5:
            health = "healthy"
        elif self.health > self.full_health * .1:
            health = "injured"
        else:
            health = "weak"
        return f"{self} looks {health}"

    def debug_inspect(self):
        import pprint
        pprint.pprint(self.__dict__)
        breakpoint()

    def vague_desc(self, value, percent):
        """ Return a vague descrption `value` as a percentage (in 0..1) of it's possible 
        range.
        
        The descrption is gets better as self.perception improves. """
        if self.perception >= 85:  # there is no guess when you are that perceptive
            return str(value)
        elif 60 <= self.perception < 85:
            bounds = [(.8, "excellent"), (.6, "good"), (.4, "average"), 
                      (.2, "mediocre,"), (0, "feeble,")]
            for floor, adj in bounds:
                if percent < floor:
                    return adj
        elif 35 <= self.perception < 60:
            bounds = [(.7, "solid"), (.4, "good"), (.2, "weak"), (0, "very weak")]
            for floor, adj in bounds:
                if percent >= floor:
                    return adj
        else:
            if value not in self._perception_cache:
                adj = rng.choice(["considerable", "substantial", "real", "so so", 
                                  "wow!", "medium", "legit", "meh"])
                self._perception_cache[value] = adj
            return self._perception_cache[value]
        
    def perceived_stats(self, other):
        """ Return a dictionary of stats for other with text value using vagueness that 
        is inversely proportional to self.perception.
        """
        stats = dict(name=str(other))
        num_attr = ["strength", "agility"]
        for attr in num_attr:
            val = getattr(other, attr)
            stats[attr] = self.vague_desc(val, val/100.0)
        stats["health"] = self.vague_desc(other.health, 
                                          other.health/other.full_health)
        return stats
        
    def stats(self):
        """ Return the core stats of an actor. """
        return dict(str=str(self), 
                    agility=self.agility, 
                    strength=self.strength, 
                    health=self.health, 
                    full_health=self.full_health)
        
    def notices(self, thing):
        """ Return whether self can notice `thing`. """
        awareness_radius = 20
        sight_radius = 30
        map = tender.engine.map
        here = map.find(self)
        there = map.find(thing)
        dist = map.distance(here, there)
        if map.line_of_sight(here, there):
            radius = sight_radius
        else:
            radius = awareness_radius

        return dist < self.perception / 100.0 * radius

    def sentiment(self, other):
        """ Return the sentiment numeric value in [-1..1]. """
        if tender.sentiments:
            return tender.sentiments.sentiment(self.faction, other.faction)
        # neutral unless we found a stronger source of information
        return 0
    
    def likes(self, other):
        """ Return whether self likes the other actor. """
        return self.sentiment(other) > self.sentiment_threshold
    
    def hates(self, other):
        """ Return whether self hates the other actor. """
        return self.sentiment(other) < -self.sentiment_threshold

    def act(self):
        """ Perform a action for this turn, return the Event summarizing 
        the action. 
        
        Return None if no action is performed.
        
        In most cases, the choice of the action is delegated to the strategy 
        while the selected action is performed by this class. """
        if self.health < 0:
            raise RuntimeError(f"{self} can't attack because of being dead!")
        if not self.strategy:
            raise RuntimeError("Trying to perform an action before assigning " 
                               "a strategy.")
        result = self.strategy.act()
        if is_action(result):
            self.set_played()
        return result
    
    def rest(self):
        self.set_played()
        return [Rest(self)]
    
    def move(self, new_pos):
        """ Move to new_pos on the map, if we can get there, raise otherwise.
        """
        map = tender.engine.map
        if map.is_free(new_pos):
            old_pos = map.find(self)
            if map.distance(old_pos, new_pos) == 1:
                map.move(self, new_pos)
                self.set_played()
                return [Move(self, old_pos, new_pos)]
            
    def pickup(self, item=None):
        """ Pickup an item from the ground. 
        
        If item is not provided, pick the first item on top of the stack. 
        """
        pos = tender.engine.map.find(self)
        stack = tender.engine.map.items_at(pos)
        if stack:
            if item is None:
                item = stack.top()
            self.inventory.append(item)
            tender.engine.map.remove(item)
            self.set_played()
            return Pickup(self, item)

    def talk(self, other):
        if other.next_dialogue:
            self.set_played()
            return Conversation(self, other, other.next_dialogue)
        return None
        
    def attack(self, foe):
        """ Do all the stikes allowed in one turn against foe. """
        if self.weapon:
            result = Events(*self.strike(foe, self.weapon))
            self.set_played()
            return result
        else:
            return None

    def strike(self, foe, weapon):
        """ Try to hit foe, another actor, with weapon. 
        Automatically adjust foe's health when there is a hit. 
        
        A single strike does not count as an action, but a full attack() does.
        """
        crit = False

        # to-hit roll
        roll = rng.normalvariate(MU, SIGMA)
        if roll < foe.get_evasion():
            return [Miss(self, foe, weapon)]

        if roll > MU+2*SIGMA:
            # critical hit!
            crit = True
        h_delta = self.make_delta(weapon, crit)

        h_delta, events = foe.apply_delta(weapon, h_delta)
        return Events(Hit(self, foe, weapon, -h_delta, crit), *events)

    def suffer_damage(self, damage):
        """ Apply some damage to self, bypassing any resistances. """
        self.health -= damage
        if self.health <= 0:
            return self.die()

    def apply_delta(self, vector, h_delta):
        """ 
        Receive damage or healing from a HealthVector.  Compute armor 
        protection, resistances, and weaknesses; update health. 
        
        Return a (delta, events) tuple.
        
        Delta is how many effective health points changed.
        Events is a instance or Events, which may include Death, or None if
        nothing notable happened.
        """
        # We don't resist healings
        events = Events()
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
            start = tender.engine.current_turn + 1
            if isinstance(effect.duration, int):
                stop = start + effect.duration
            else:
                stop = start + rng.randint(*effect.duration)
            cond = Condition(effect, start, stop, cond_delta)
            self.conditions.append(cond)
        
        if self.health <= 0:
            events.add(self.die())

        return h_delta, events

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

        return (1 + (stat - MU)/100.0) * h_delta * rng.random()

    def die(self):
        """ 
        Perpare the actor for the passage into the underworld, then expire.
        """
        if not tender.engine:
            raise RuntimeError("Passing into the underworld requires being part"
                               " of a world to begin with.")
        
        # drop inventory
        if tender.engine.map:
            pos = tender.engine.map.find(self)
            for i in self.inventory:
                tender.engine.map.place(i, pos)
        self.inventory = []
        # TODO: keep 1g when money is implemented.  The passage into the 
        # underworld must be paid.
        
        # pass the control to the engine
        tender.engine.to_charon(self)
        return Death(self)


class Monster(Actor):
    """ Monsters follow their instinct; they do not posses soffisticated 
    aspirations nor ethics. """
    char = "x"
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
        h_delta, events = target.apply_delta(spell, h_delta)
        self.mana -= spell.cost
        return Events(Hit(self, target, spell, -h_delta), events)


class Humanoid(Character):
    """ Your average human shapped creature. 
    Most creatures of that shape know how to throw a punch. """
    char = "@"
    def __init__(self, health, armor, strength, agility, intelligence, fist_r=4, fist_l=None):
        super(Humanoid, self).__init__(health, armor, strength, agility, intelligence)
        if fist_r:
            self.fist_r = Injurious("fist", fist_r, Families.IMPACT)
        else:
            self.fist_r = None

        if fist_l:
            self.fist_l = Injurious("fist", fist_l, Families.IMPACT)
        else:
            self.fist_l = None
            
    def attack(self, foe):
        if self.weapon:
            return self.strike(foe, self.weapon)
        else:
            hits = Events()
            if self.fist_r:
                hits += self.strike(foe, self.fist_r)
            if self.fist_l:
                hits += self.strike(foe, self.fist_l)
            return hits or None
