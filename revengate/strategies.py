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

from . import tender
from .randutils import rng

class SelectionCache:
    """ A placeholder for various properties about a target so we don't keep 
    recomputing it. """
    def __init__(self, actor, target):
        self.map = tender.engine.map
        self.actor = actor
        self.target = target
        self._pos_a = self.map.find(actor)
        self._pos_t = self.map.find(target)
        self._dist = None
        self._los = None
        self._path = None

    @property
    def dist(self):
        if self._dist is None:
            self._dist = self.map.distance(self._pos_a, self._pos_t)
        return self._dist

    @property
    def los(self):
        if self._los is None:
            self._los = self.map.line_of_sight(self._pos_a, self._pos_t)
        return self._los

    @property
    def path(self):
        if self._path is False:
            # we know for sure that there is no way to reach the target
            return None
        if self._path is None:
            path = self.map.path(self._pos_a, self._pos_t)
            if path is None:
                self._path = False
                return None
            else:
                self._path = list(path)
        return self._path


class Strategy:
    """ A play strategy to automate an actor's actions. """
    
    def __init__(self, name, actor=None):
        super(Strategy, self).__init__()
        self.name = name
        self.actor = actor

    def act(self):
        map = tender.engine.map
        actors = map.all_actors()  # TODO: ignore the out of sight ones
        tc = self.select_target(actors)
        if tc:
            if tc.dist == 1:
                return self.actor.attack(tc.target)
            else:
                path = tc.path
                if path:
                    return self.actor.move(path[1])
        # Rest when there nothing better to do
        return self.actor.rest()
        
    def select_target(self, targets):
        raise NotImplementedError()


class StrategySlot:
    """ 
    A placeholder for a Strategy that registers the actor with the Strategy.

    This is using the descriptor protocol and should be set as a class 
    attribute.
    """
    def __init__(self, strategy=None):
        super(StrategySlot, self).__init__()
        self.slot = None

    def __set_name__(self, owner, name):
        self.slot = '_' + name

    def __get__(self, obj, objtype=None):
        return getattr(obj, self.slot)

    def __set__(self, obj, strategy):
        if not isinstance(strategy, Strategy):
            raise ValueError(f"Unsupported type for strategy: {type(strategy)}")
        if strategy.actor is not None:
            raise ValueError(f"{strategy} already has a registered actor.")
        strategy.actor = obj
        setattr(obj, self.slot, strategy)
        
        
class AttackOriented(Strategy):
    """ Does nothing but looking for some to attack. """

    def is_enemy(self, target):
        """ Return whether a target actor should be considered an enemy. """
        raise NotImplementedError()
        
    def select_target(self, targets):
        # TODO: tune-down the awareness and only start chasing a target if you 
        #       can reasonably suspect where it is
        options = [SelectionCache(self.actor, t) 
                   for t in targets
                   if self.is_enemy(t)]
        # path finding is very expensive, so we start by looking at 
        # map.distance() to find a smaller set, then we sort by actual path
        # finding.
        options.sort(key=lambda x: x.dist)
        short_list = []
        for opt in options:
            if opt.dist == 1:
                return opt
            elif opt.path:
                short_list.append(opt)
                if len(short_list) == 5:
                    break
        if short_list:
            short_list.sort(key=lambda x: len(x.path))
            return short_list[0]
        else:
            return None  # no one to attack
        

class Tribal(AttackOriented):
    """ Attack anyone not in the same faction. """

    def is_enemy(self, target):
        """ Return whether a target actor should be considered an enemy. """
        return target.faction != self.actor.faction


class PoliticalHater(AttackOriented):
    """ Attack anyone if their faction thinks poorly of them. """

    def is_enemy(self, target):
        """ Return whether a target actor should be considered an enemy. """
        return self.actor.hates(target)


class Wandering(Strategy):
    """ Roam around aimlessly. """
    rest_bias = 0.2  # rest instead a moving once in a while

    def __init__(self, name, actor=None):
        super().__init__(name, actor)
        self.waypoint = None
    
    def act(self):
        # A more interesting way to go about this would be to look at the recent forced 
        # rests events and to base the current rest bias on that.
        if rng.rstest(self.rest_bias):
            return self.actor.rest()
        
        map = tender.engine.map
        if not self.waypoint:
            self.waypoint = map.random_pos(free=True)
            
        here = map.find(self.actor)
        path = map.path(here, self.waypoint)
        if path:
            res = self.actor.move(path[1])
            if len(path) <= 2:
                self.waypoint = None
            return res
        else:
            # FIXME be more explicit
            return self.actor.rest()
