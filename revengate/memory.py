# Copyright © 2022 Yannick Gingras <ygingras@ygingras.net> and contributors

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

""" How we store everything that happened to an actor """

# Design
# - events.StatusEvent has almost all the info that we need, we just need to save then 
#   when they occur
# - event.ttl can allow us to garbage collect stale events
# - do not store explicit object references to keep it pickleable

# Use Cases:
# - actor wants to know who is the last person to hit them
# - monster goes back to a safe spot that it knows about
# - repeat the previous attack that proved the most effective, not necessarily the last 
#   one
# - player reviews important quest goals / hints (maybe not for the memory class)
# - find the nearest exit out of a level (based on knowledge of the level, not the 
#   current level)

from collections import deque


class Memory:
    def __init__(self, actor):
        self.actor = actor
        self.events = deque()
        # TODO cache query answers in between the adding or subtracting of events

    def append(self, event):
        self.events.append(event)

    def last_attacker(self):
        """ Return the last actor to attack self.actor. """
        for event in reversed(self.events):
            if hasattr(event, "attacker") and event.attacker_id != self.actor.id:
                if attacker := event.attacker:
                    return attacker

    def attackers(self, events_ago=None):
        """ Return a set of actors who attacked self.actor since events_ago.
        
        If events_ago is None: search the whole memory. 
        """
        nb_events = len(self.events)
        if events_ago is None:
            events_ago = nb_events
        attackers = set()
        for i in range(nb_events-1, nb_events-1-events_ago, -1):
            event = self.events[i]
            if hasattr(event, "attacker") and event.attacker_id != self.actor.id:
                if attacker := event.attacker:
                    attackers.add(attacker)
        return attackers
        
    def last_victim(self):
        for event in reversed(self.events):
            if hasattr(event, "victim") and event.victim_id != self.actor.id:
                if victim := event.victim:
                    return victim
        
