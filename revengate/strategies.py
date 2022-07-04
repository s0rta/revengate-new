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

""" Various ways to decide who to attack and how to attack them. """

from functools import partial
from operator import attrgetter

from . import events
from .utils import best
from . import tender
from .randutils import rng


class SelectionCache:
    """ A placeholder for various properties about a target so we don't keep 
    recomputing it. """

    def __init__(self, me, other):
        self.me = me
        self.other= other
        self._pos_me = tender.engine.map.find(me)
        self._pos_other = tender.engine.map.find(other)
        self._dist = None
        self._los = None
        self._path = None

    @property
    def dist(self):
        map = tender.engine.map
        if self._dist is None:
            self._dist = map.distance(self._pos_me, self._pos_other)
        return self._dist

    @property
    def pos(self):
        return self._pos_other
    
    @property
    def los(self):
        map = tender.engine.map
        if self._los is None:
            self._los = map.line_of_sight(self._pos_me, self._pos_other)
        return self._los

    @property
    def path(self):
        map = tender.engine.map
        if self._path is False:
            # we know for sure that there is no way to reach the target
            return None
        if self._path is None:
            path = map.path(self._pos_me, self._pos_other)
            if path is None:
                self._path = False
                return None
            else:
                self._path = list(path)
        return self._path


class Strategy:
    """ A play strategy to automate an actor's actions. """
    priority = 0.5  # in [0..1] for normal circumstances 
    
    def __init__(self, name, me=None):
        super(Strategy, self).__init__()
        self.name = name
        self.me = me
        self.ttl = None
        
    def is_valid(self):
        """ Return whether the strategy is a valid one for `me` at the present time. """
        return True

    def is_expired(self):
        """ Return whether the strategy has outlived it's usefulness. 
        
        Expired strategies won't become valid ever again and are deleted by the actor. 
        
        Sub-classes that implement an expiration logic should override this method.
        """
        if self.ttl is not None and self.ttl <= 0:
            return True
        else:
            return False
        
    def update(self):
        """ Inspect the state of the world and adjust internal parameters. 
        
        Sub-classes should override this.
        """
        pass
        
    def assign(self, me):
        """ Assign the strategy to the Actor `me`. """
        self.me = me

    def act(self):
        if self.ttl is not None:
            self.ttl -= 1

        map = tender.engine.map
        actors = map.all_actors()  # TODO: ignore the out of sight ones
        sel = self.select_other(actors)
        if sel:
            if sel.dist == 1:
                return self.me.attack(sel.other)
            else:
                path = sel.path
                if path:
                    return self.me.move(path[1])
        # Rest when there nothing better to do
        return self.me.rest()
        
    def is_interesting(self, other):
        return NotImplementedError()

    def select_other(self, others):
        # TODO: tune-down the awareness and only start chasing a target if you 
        #       can reasonably suspect where it is
        options = [SelectionCache(self.me, other) 
                   for other in others
                   if self.is_interesting(other)]
        # path finding is very expensive, so we start by looking at 
        # map.distance() to find a smaller set, then we sort by actual path
        # finding.
        options.sort(key=attrgetter("dist"))
        short_list = []
        for opt in options:
            if opt.dist == 1:
                return opt
            elif opt.path:
                short_list.append(opt)
                if len(short_list) == 5:
                    break
        if short_list:
            return best(short_list, attrgetter("path"), True)
        else:
            return None  # no one to attack

        
class AttackOriented(Strategy):
    """ Does nothing but looking for some to attack. """

    def is_enemy(self, other):
        """ Return whether an other actor should be considered an enemy by me. """
        raise NotImplementedError()
        
    def is_interesting(self, other):
        """ Return whether other should be considered as a potential selection. """
        return self.is_enemy(other)
                

class Tribal(AttackOriented):
    """ Attack anyone not in my faction. """

    def is_enemy(self, other):
        """ Return whether a target actor should be considered an enemy. """
        return self.me.faction != other.faction


class PoliticalHater(AttackOriented):
    """ Attack any other if my faction thinks poorly of them. """

    priority = 0.2

    def is_enemy(self, other):
        """ Return whether a target actor should be considered an enemy. """
        return self.me.hates(other)


class Wandering(Strategy):
    """ Roam around aimlessly. """
    rest_bias = 0.2  # rest instead a moving once in a while

    def __init__(self, name):
        super().__init__(name)
        self.waypoint = None
    
    def act(self):
        if self.ttl is not None:
            self.ttl -= 1
        # A more interesting way to go about this would be to look at the recent forced 
        # rests events and to base the current rest bias on that.
        if rng.rstest(self.rest_bias):
            return self.me.rest()
        
        map = tender.engine.map
        if not self.waypoint:
            self.waypoint = map.random_pos(free=True)
            
        here = map.find(self.me)
        path = map.path(here, self.waypoint)
        if path:
            res = self.me.move(path[1])
            if len(path) <= 2:  # we got to our destination
                self.waypoint = None
            return res
        else:
            # FIXME be more explicit
            return self.me.rest()


class Fleeing(Strategy):
    """ Run away from an attacker. """

    priority = 0.75

    def is_valid(self):
        map = tender.engine.map
        my_pos = map.find(self.me)
        for pos in map.adjacents(my_pos, free=False):
            threat = map.actor_at(pos)
            if threat and threat.hates(self.me):
                return True
        return False

    def is_interesting(self, other):
        return self.is_menacing(other)

    def is_menacing(self, other):
        """ Return whether a target actor should be considered an enemy. """
        return other.hates(self.me)

    def act(self):
        self.update()
        map = tender.engine.map
        others = map.all_actors()  # TODO: ignore the out of sight ones
        threat = self.select_other(others)
        
        if threat:
            my_pos = map.find(self.me)
            next_positions = map.adjacents(my_pos, free=True)
            if next_positions:
                dist_f = partial(map.distance, threat.pos)
                there = best(next_positions, key=dist_f)
                return self.me.move(there)
        # TODO: be explicit that we have no other options
        return self.me.rest()


class Panicking(Fleeing):
    yell_frequency = 5
    
    def __init__(self, name):
        super().__init__(name)
        self.last_yell = None

    def act(self):
        if self.ttl is not None:
            self.ttl -= 1
        cur_turn = tender.engine.current_turn
        if self.last_yell is None or self.last_yell < cur_turn - self.yell_frequency:
            self.last_yell = cur_turn
            self.me.set_played()
            return [events.Yell(self.me, "I'm out, you win!!")]
        
        map = tender.engine.map
        others = map.all_actors()  # TODO: ignore the out of sight ones
        threat = self.select_other(others)
        
        if threat:
            my_pos = map.find(self.me)
            next_positions = map.adjacents(my_pos, free=True)
            if next_positions:
                dist_f = partial(map.distance, threat.pos)
                there = best(next_positions, key=dist_f)
                return self.me.move(there)
        # TODO: be explicit that we have no other options
        return self.me.rest()

    def is_valid(self):
        return True


class SelfDefense(AttackOriented):
    """ Attack back if has been attacked. """
    priority = 0.6

    def is_valid(self):
        return bool(self.me.memory.attackers())

    def is_enemy(self, other):
        """ Return whether an other actor should be considered an enemy by me. """
        return other in self.me.memory.attackers()
        
    def is_interesting(self, other):
        """ Return whether other should be considered as a potential selection. """
        return self.is_enemy(other)


class FlightOrFight(Strategy):
    """ Flee, but fight back when cornered. """
    priority = 0.8
    calm_down_turns = 20

    def __init__(self, name):
        super().__init__(name)
        self.last_threatened = 0  # how many turns since we've seen our attacker?
        
    def act(self):
        if self.ttl is not None:
            self.ttl -= 1
            
        map = tender.engine.map
        my_pos = map.find(self.me)
        foe = self.me.memory.last_attacker()
        if not foe or not self.me.notices(foe):
            # this should not happen if self.is_valid() did the right thing
            return self.me.rest()

        foe_pos = map.find(foe)
        dist_f = partial(map.distance, foe_pos)
        my_dist = dist_f(my_pos)

        options = []
        for pos in map.adjacents(my_pos, free=True, shuffle=True):
            dist = dist_f(pos)
            if dist > my_dist:
                options.append((dist, pos))

        if options:
            # move the furthest away we can
            options = sorted(options, reverse=True)
            _, pos = options[0]
            return self.me.move(pos)
        else:
            # Can't move! Attack the main threat, or anyone else if it gets to that...
            if my_dist == 1:
                return self.me.attack(foe)
            else:
                for pos in map.adjacents(my_pos, free=False):
                    if bystander:=map.actor_at(pos):
                        return self.me.attack(bystander)
        return self.me.rest()  # wait for a turn when everything else seems impossible
        
    def update(self):
        super().update()
        foe = self.me.memory.last_attacker()
        if foe and self.me.notices(foe):
            self.last_threatened = 0
        else:
            self.last_threatened += 1

    def is_valid(self):
        if self.calm_down_turns <= self.last_threatened:
            return False
        
        if self.me.health_percent < .2 or self.me.health <= 2:
            if self.me.memory.last_attacker():
                return True
        return False


class Paralyzed(Strategy):
    """ Can't do anything """
    priority = 0.85

    def __init__(self, name):
        super().__init__(name)
        
    def act(self):
        if self.ttl is not None:
            self.ttl -= 1
            
        # FIXME: should be a forced rest, slightly different
        return self.me.rest()  
        
