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
from .combat_defs import RES_FACTOR, Families
from .effects import Condition, Injurious, EffectVector
from .weapons import Weapon, Spell
from .events import (Hit, Miss, Events, HealthEvent, Move, Rest, Death, is_action, 
                     Pickup, Conversation)
from .items import Item, ItemsSlot
from . import tender, strategies


SIGMA = 12.5  # std. dev. for a normal distribution more or less contained in 0..100
MU = 50  # average of the above distribution


class Actor(object):
    """ Base class of all actors. """
    # everyone defaults to 35% more damage with a critical hit
    critical_mult = 0.35 
    # how strong your sentiment has to be to move from neutral 
    sentiment_threshold = 0.75  
    faction = TagSlot(FactionTag)
    inventory = ItemsSlot()
    char = "X"  # How to render this actor on the text map

    def __init__(self, health, armor, strength, agility, 
                 perception=50, healing_factor=0.05):
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
        self._strength = strength
        self._agility = agility
        self._perception = perception
        self._perception_cache = {}  # value -> perceived_text
        # prob in 0..1 that you will heal 1HP at the start of a turn
        self.healing_factor = healing_factor

        self.resistances = TagBag('Family')
        self._weapon = None

        # taxon and identifiers
        self.species = None
        self.role = None
        self.rank = None
        self.name = None
        
        # presentation, lore, bestiary entry
        self.color = "CCCCCC"
        self.bestiary_img = None
        self.desc = ""

        # dialogues and conversations
        self.next_dialogue = None
        self.convo_topics = TagBag('ConvoTopic')

        # turns logic
        self.initiative = rng.random()
        self._last_action = None  # last turn when self made an action
        self._last_update = None  # last time we computed conditions and regen
        self.conditions = []      # mostly stuff that does damage over time

    def __hash__(self):
        return hash(self.id)

    @property
    def strategy(self):
        self._strategies = [strat for strat in self._strategies 
                            if not strat.is_expired()]
        if self._strategies:
            key=attrgetter("priority")
            strats = [strat for strat in self._strategies if strat.is_valid()]
            if strats:
                return best(strats, key)
        
    def _get_strategies(self):
        return self._strategies
        
    def _set_strategies(self, strategies):
        for strat in strategies:
            strat.assign(self)
        self._strategies = strategies
    strategies = property(_get_strategies, _set_strategies)

    # TODO: notes from 2022-07-18 have a better way to generalize those
    def _get_strength(self):
        delta = 0
        for cond in self.conditions:
            if cd := cond.attribute_delta("strength"):
                delta += cd
        return self._strength + delta
        
    def _set_strength(self, strength):
        """ Set permanent strength of the actor without taking conditions into 
        account. """
        self._strength = strength
    strength = property(_get_strength, _set_strength)

    def _get_agility(self):
        delta = 0
        for cond in self.conditions:
            if cd := cond.attribute_delta("agility"):
                delta += cd
        return self._agility + delta
        
    def _set_agility(self, agility):
        """ Set permanent agility of the actor without taking conditions into 
        account. """
        self._agility = agility
    agility = property(_get_agility, _set_agility)

    def _get_perception(self):
        delta = 0
        for cond in self.conditions:
            if cd := cond.attribute_delta("perception"):
                delta += cd
        return self._perception + delta
        
    def _set_perception(self, perception):
        """ Set permanent perception of the actor without taking conditions into 
        account. """
        self._perception = perception
    perception = property(_get_perception, _set_perception)

    def _get_weapon(self):
        return self._weapon
    
    def _set_weapon(self, weapon):
        # Add the new weapon to the inventory if it's an item and it's not already 
        # there. Non-item weapons include body parts on animals, like claws and bites.
        if isinstance(weapon, Item) and weapon not in self.inventory:
            self.inventory.append(weapon)
        self._weapon = weapon
    weapon = property(_get_weapon, _set_weapon)
    
    @property
    def is_alive(self):
        return self.health > 0

    @property
    def is_dead(self):
        return self.health <= 0

    @property
    def is_hyper_perceptive(self):
        return self.perception >= 85

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
        start = (self._last_update or 0) + 1
        for t in range(start, tender.engine.current_turn + 1):
            events += self._update_one(t)
        if self.health <= 0:
            events.add(self.die())
        return events
    
    def _update_one(self, turn):
        """
        Compute one the effect of turn worth of long term conditions.
        
        Return the summary of health changes.
        """
        if self._last_update is not None and turn <= self._last_update:
            raise RuntimeError(f"Attempt to double-update {self!r} on turn {turn}.")
        
        events = Events()
        if rng.rstest(self.healing_factor) and self.health < self.full_health:
            self.health += 1
            events.add(HealthEvent(self, 1))
        
        for cond in self.conditions:
            if cond.is_active(turn):
                self.health += cond.h_delta
                events.add(HealthEvent(self, cond.h_delta))
        self.conditions = [c for c in self.conditions if not c.is_expired(turn)]
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

    def __repr__(self):
        return f"<{self.__class__.__name__} {self}>"
    
    @property
    def health_percent(self):
        """ Return the percentage from full_health. Typically in 0..1, but can go above 
        in rare cases. """
        return self.health / self.full_health
    
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
        if self.is_hyper_perceptive:  
            # there's no guessing when you are that perceptive
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
        return dict(str=self.__str__(), 
                    agility=self.agility, 
                    strength=self.strength, 
                    health=self.health, 
                    full_health=self.full_health)
    
    def remember(self, event):
        self.memory.append(event)
        
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

    def update_strategies(self):
        """ Refresh the internal caches of all strategies to reflectly the current state 
        of the world.
        
        act() calls this automatically, but it can also be called manually before 
        introspecting strategies.
        """
        for strat in self._strategies:
            strat.update()

    def act(self, update_strats=True):
        """ Perform a action for this turn, return the Event summarizing 
        the action. 
        
        Return None if no action is performed.
        
        In most cases, the choice of the action is delegated to the strategy 
        while the selected action is performed by this class. """
        if self.health < 0:
            raise RuntimeError(f"{self} can't act because of being dead!")
        
        if update_strats:
            self.update_strategies()
        strat = self.strategy
        if not strat:
            raise RuntimeError("Trying to perform an action without a valid strategy.")
        
        result = strat.act()
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
    
    def travel(self, dest):
        """ Start the multi-turn travel to dest, return the result of the first move. 
        """
        strat = strategies.Traveling("traveling", dest, self)
        self.strategies.append(strat)
        return self.act()
    
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

    def use_item(self, item, voluntary=True):
        """ Use an item.

        The actor might use it voluntarily or be forced to use it, like having a potion 
        thrown at them.
        """
        res = Events(*item.use(self, voluntary))
        if item.is_consumed and item in self.inventory:
            self.inventory.remove(item)
        if isinstance(item, EffectVector):
            delta, effect_res = self.apply_delta(item, item.h_delta)
            res += effect_res
        self.set_played()
        return res

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
        Receive damage or healing from an EffectVector.  Compute armor 
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
            if not rng.rstest(effect.prob):
                continue
            cond_delta = effect.h_delta
            # TODO: eff.apply() should be the API to use regardless of permanence
            if effect.permanent:
                effect.apply(self, tender.engine.current_turn + 1)
            else:
                # TODO: expose a more abstract API to let the effect materialize itself on the actor
                # materialization is for long term influence of the effect
                mat = effect.materialize(tender.engine.current_turn + 1, 
                                         self.resistances)
                if isinstance(mat, Condition):
                    self.conditions.append(mat)
                else:
                    mat.assign(self)
                    self.strategies.append(mat)

        
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
        self.inventory.clear()
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

    def __init__(self, health, armor, strength, agility, intelligence, 
                 fist_r=4, fist_l=None):
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
