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
    
    def __init__(self, name):
        super(Strategy, self).__init__()
        self.name = name
        
    def is_valid(self, me):
        """ Return whether the strategy is a valid one for `me` at the present time. """
        return True

    def act(self, me):
        map = tender.engine.map
        actors = map.all_actors()  # TODO: ignore the out of sight ones
        sel = self.select_other(me, actors)
        if sel:
            if sel.dist == 1:
                return me.attack(sel.other)
            else:
                path = sel.path
                if path:
                    return me.move(path[1])
        # Rest when there nothing better to do
        return me.rest()
        
    def is_interesting(self, me, other):
        return NotImplementedError()

    def select_other(self, me, others):
        # TODO: tune-down the awareness and only start chasing a target if you 
        #       can reasonably suspect where it is
        options = [SelectionCache(me, other) 
                   for other in others
                   if self.is_interesting(me, other)]
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

    def is_enemy(self, me, other):
        """ Return whether a other actor should be considered an enemy by me. """
        raise NotImplementedError()
        
    def is_interesting(self, me, other):
        """ Return whether other should be considered as a potential selection. """
        return self.is_enemy(me, other)
                

class Tribal(AttackOriented):
    """ Attack anyone not in my faction. """

    def is_enemy(self, me, other):
        """ Return whether a target actor should be considered an enemy. """
        return me.faction != other.faction


class PoliticalHater(AttackOriented):
    """ Attack any other if my faction thinks poorly of them. """

    priority = 0.2

    def is_enemy(self, me, other):
        """ Return whether a target actor should be considered an enemy. """
        return me.hates(other)


class Wandering(Strategy):
    """ Roam around aimlessly. """
    rest_bias = 0.2  # rest instead a moving once in a while

    def __init__(self, name):
        super().__init__(name)
        self.waypoint = None
    
    def act(self, me):
        # A more interesting way to go about this would be to look at the recent forced 
        # rests events and to base the current rest bias on that.
        if rng.rstest(self.rest_bias):
            return me.rest()
        
        map = tender.engine.map
        if not self.waypoint:
            self.waypoint = map.random_pos(free=True)
            
        here = map.find(me)
        path = map.path(here, self.waypoint)
        if path:
            res = me.move(path[1])
            if len(path) <= 2:  # we got to our destination
                self.waypoint = None
            return res
        else:
            # FIXME be more explicit
            return me.rest()


class Fleeing(Strategy):
    """ Run away from an attacker. """

    priority = 0.75

    def is_valid(self, me):
        map = tender.engine.map
        my_pos = map.find(me)
        for pos in map.adjacents(my_pos, free=False):
            threat = map.actor_at(pos)
            if threat and threat.hates(me):
                return True
        return False

    def is_interesting(self, me, other):
        return self.is_menacing(me, other)

    def is_menacing(self, me, other):
        """ Return whether a target actor should be considered an enemy. """
        return other.hates(me)

    def act(self, me):
        map = tender.engine.map
        others = map.all_actors()  # TODO: ignore the out of sight ones
        threat = self.select_other(me, others)
        
        if threat:
            my_pos = map.find(me)
            next_positions = map.adjacents(my_pos, free=True)
            if next_positions:
                dist_f = partial(map.distance, threat.pos)
                there = best(next_positions, key=dist_f)
                return me.move(there)
        # TODO: be explicit that we have no other options
        return me.rest()


class Panicking(Fleeing):
    yell_frequency = 5
    
    def __init__(self, name):
        super().__init__(name)
        self.last_yell = None

    def act(self, me):
        cur_turn = tender.engine.current_turn
        if self.last_yell is None or self.last_yell < cur_turn - self.yell_frequency:
            self.last_yell = cur_turn
            me.set_played()
            return [events.Yell(me, "I'm out, you win!!")]
        
        map = tender.engine.map
        others = map.all_actors()  # TODO: ignore the out of sight ones
        threat = self.select_other(me, others)
        
        if threat:
            my_pos = map.find(me)
            next_positions = map.adjacents(my_pos, free=True)
            if next_positions:
                dist_f = partial(map.distance, threat.pos)
                there = best(next_positions, key=dist_f)
                return me.move(there)
        # TODO: be explicit that we have no other options
        return me.rest()

    def is_valid(self, me):
        return True


class SelfDefence(AttackOriented):
    """ Attack back if has been attacked. """

    # FIXME this one relies on inspection of previous events
    def is_enemy(self, me, other):
        """ Return whether a other actor should be considered an enemy by me. """
        raise NotImplementedError()
        
    def is_interesting(self, me, other):
        """ Return whether other should be considered as a potential selection. """
        return self.is_enemy(me, other)
