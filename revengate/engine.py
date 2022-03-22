#! /usr/bin/env python3

# Copyright © 2020–2022 Yannick Gingras <ygingras@ygingras.net>

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


import itertools
import operator

from .weapons import Events
from . import tender

class Engine(object):
    """ Keep track of all the actors and implement the turns logic. """
    
    def __init__(self):
        super(Engine, self).__init__()
        self._actors = []  # actors who are not on the map but we still track
        self.current_turn = 0
        self.map = None

    def __getstate__(self):
        """ Return a representation of the internal state that is suitable for the 
        pickling protocol. """
        state = self.__dict__.copy()
        # Remove the unpicklable entries.
        for key in ["map"]:
            del state[key]
        return state

    def __setstate__(self, state):
        """ Restore an instance from a pickled state.
        
        `map` is not restored. The governor or simulator is in charge or 
        restoring this attributes. """

        self.__dict__.update(state)

    def all_actors(self):
        if self.map:
            actors = itertools.chain(self._actors, self.map.all_actors())
        else:
            actors = self._actors
        return sorted(actors, key=operator.attrgetter("initiative"))

    def register(self, actor):
        """ Register an actor with this engine. """
        if self.map is not None and actor in self.map:
            raise RuntimeError(f"{actor} is already on the active map. Only off-map "
                               "actors should be manually registered with the engine. ")
        self._actors.append(actor)

    def deregister(self, actor):
        self._actors = [a for a in self._actors if a != actor]

    def advance_turn(self):
        """ Update everything that needs to be updated at the start of a new
        turn. """
        self.current_turn += 1
        events = Events()
        for actor in self.all_actors():
            events += actor.update()
        return events

    def change_map(self, map):
        # TODO: save the status of the old map so we can go back to it
        self.map = map

    def to_charon(self, actor):
        # TODO: take payment for the toll across the Styx
        if self.map:
            pos = self.map.find(actor)
            self.map.remove(actor)
            corpse = tender.loader.invoke("corpse")
            self.map.place(corpse, pos)
        self.deregister(actor)

