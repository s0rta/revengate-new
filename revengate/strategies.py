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

class Strategy:
    """ A play strategy to automate an actor's actions. """
    def __init__(self, name, actor=None):
        super(Strategy, self).__init__()
        self.name = name
        self.actor = actor
        
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
        self.strategy = strategy
        self.slot = None

    def __set_name__(self, owner, name):
        self.slot = '_' + name

    def __get__(self, obj, objtype=None):
        return getattr(obj, self.slot)

    def __set__(self, obj, strategy):
        if strategy.actor is not None:
            raise ValueError(f"{strategy} already has a registered actor.")
        strategy.actor = obj
        setattr(obj, self.slot, strategy)
        
        
class Tribal(Strategy):
    """ Attack anyone not in the same faction. """
    def select_target(self, targets):
        for t in targets:
            if t.faction != self.actor.faction:
                return t
        return None # no one to attack

