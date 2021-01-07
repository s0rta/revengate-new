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

""" Various ways to decide who to attack and how to attack them. """

class SelectionCache:
    """ A placeholder for various properties about a target so we don't keep 
    recomputing it. """
    def __init__(self, map, actor, target):
        self.map = map
        self.actor = actor
        self.target = target
        self._pos_a = map.find(actor)
        self._pos_t = map.find(target)
        self._dist = None
        self._los = None
        self._path = None
        
    @property
    def dist(self):
        if self._dist == None:
            self._dist = self.map.distance(self._pos_a, self._pos_t)
        return self._dist

    @property
    def los(self):
        if self._los == None:
            self._los = self.map.line_of_sight(self._pos_a, self._pos_t)
        return self._los

    @property
    def path(self):
        if self._path == None:
            self._path = list(self.map.path(self._pos_a, self._pos_t))
        return self._path

class Strategy:
    """ A play strategy to automate an actor's actions. """
    def __init__(self, name, actor=None):
        super(Strategy, self).__init__()
        self.name = name
        self.actor = actor

    def act(self, map):
        actors = map.all_actors() # TODO: ignore the out of sight ones
        tc = self.select_target(map, actors)
        if tc:
            if tc.dist == 1:
                return self.actor.attack(tc.target)
            else:
                path = tc.path
                if path:
                    return self.actor.move(map, path[1])
        
    def select_target(self, map, targets):
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
        
        
class Tribal(Strategy):
    """ Attack anyone not in the same faction. """
    def select_target(self, map, targets):
        pos = map.find(self.actor)
        # TODO: tune-down the awareness and only start chasing a target if you 
        #       can reasonably suspect where it is
        options = [SelectionCache(map, self.actor, t) 
                   for t in targets
                   if t.faction != self.actor.faction]
        # path finding is very expensive, so we start by looking at 
        # map.distance() to find a smaller set, then we sort by actually path
        # finding.
        options.sort(key=lambda x:x.dist)
        short_list = []
        for opt in options:
            if opt.dist == 1:
                return opt
            elif opt.path:
                short_list.append(opt)
                if len(short_list) == 5:
                    break
        if short_list:
            short_list.sort(key=lambda x:len(x.path))
            return short_list[0]
        else:
            return None # no one to attack

