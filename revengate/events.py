# Copyright © 2020-2022 Yannick Gingras <ygingras@ygingras.net>

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

""" Events keep track of everything that change.  This allows the game to  if Events 
display or animate the changes. """


def is_action(event):
    """ Return whether event (or Events) counts as a turn action. """
    return isinstance(event, (Events, StatusEvent)) and bool(event)


class StatusEvent:
    """ Something that changes the status of an actor. 
    
    This is mostly to keep track of what happened so we can show it to the 
    player. 
    
    Any function that could return a StatusEvent can also return None if the 
    event didn't occur. 
    
    actor: either the performer or the victim of the action. Sub-classes are encouraged 
    to make this obivous by renaming contructor arguments and possibly aliasing instance 
    attributes.    
    """
    
    def __init__(self, actor):
        super(StatusEvent, self).__init__()
        self.actor = actor

class Events:
    """ A group of StatusEvents.  None-events are implicitely ignored. """
    def __init__(self, *events):
        super(Events, self).__init__()
        self._events = []
        for e in events:
            if e:
                if isinstance(e, Event):
                    self._events.append(e)
                else:
                    self._events += e
        
    def __str__(self):
        return " ".join(map(str, self))
       
    def __iadd__(self, other):
        other = filter(bool, other)
        self._events += other
        return self
    
    def __bool__(self):
        return len(self._events) > 0
    
    def __iter__(self):
        return iter(self._events)
    
    def add(self, event):
        if event:
            self._events.append(event)


class Move(StatusEvent):
    """ The actor moved. """
    def __init__(self, performer, old_pos, new_pos):
        super().__init__(performer)
        self.old_pos = old_pos
        self.new_pos = new_pos
        
    def __str__(self):
        return f"{self.actor} moved from {self.old_pos} to {self.new_pos}."


class StairsEvent(StatusEvent):
    """ The actor took a flight of stairs. """
    def __init__(self, performer, from_pos):
        super().__init__(performer)
        self.from_pos = from_pos
        
    def __str__(self):
        return f"{self.actor} followed stairs at {self.from_pos}."


class Rest(StatusEvent):
    """ The actor did nothing. """        
    def __str__(self):
        return f"{self.actor} waits patiently."


class Death(StatusEvent):
    """ The actor died. """
    def __init__(self, victim):
        super().__init__(victim)
        
    def __str__(self):
        return f"{self.actor} died!"


class HealthEvent(StatusEvent):
    """ The actor's health just got better or worse. """
    def __init__(self, actor, h_delta):
        super().__init__(actor)
        self.h_delta = h_delta
        
    def __str__(self):
        if self.h_delta >= 0:
            return f"{self.actor} heals {self.h_delta} points."
        else:
            return (f"{self.actor} suffers {-self.h_delta} damages" 
                    " from injuries.")
                        

class Injury(HealthEvent):
    """ Something that hurts """
    def __init__(self, victim, damage):
        super().__init__(victim, -damage)

    @property
    def damage(self):
        return -self.h_delta
        
    @property
    def victim(self):
        return self.actor


class Hit(Injury):
    """ A successful hit with a weapon. """
    def __init__(self, attacker, victim, weapon, damage, critical=False):
        super().__init__(victim, damage)
        self.attacker = attacker
        self.weapon = weapon
        self.critical = critical
        
    def __str__(self):
        s = (f"{self.attacker} hit {self.victim} with a {self.weapon}"
             f" for {self.damage} damages!")
        if self.critical:
            s += " Critical hit!"
        return s


class Miss(StatusEvent):
    """ Tried to attack, but didn't make contact with the target. """
    def __init__(self, attacker, target, weapon):
        super().__init__(attacker)
        self.target = target
        self.weapon = weapon
        
    def __str__(self):
        return f"{self.actor} misses {self.target}."


class InventoryChange(StatusEvent):
    """ Added or lossed something form the inventory """
    def __init__(self, actor, item):
        super().__init__(actor)
        self.item = item
        
    def __str__(self):
        return f"{self.item} changed possession."


class Pickup(InventoryChange):
    """ Picked something from the ground """
    def __init__(self, actor, item):
        super().__init__(actor, item)
        
    def __str__(self):
        return f"Picked {self.item} from the ground."


class Events(list):
    """ A group of StatusEvents.  None-events are implicitly ignored. """
    def __init__(self, *events):
        if events:
            events = filter(bool, events)
            super(Events, self).__init__(events)
        else:
            super(Events, self).__init__()
        
    def __str__(self):
        return " ".join(map(str, self))
       
    def __iadd__(self, other):
        other = filter(bool, other)
        return super(Events, self).__iadd__(other)
    
    def add(self, event):
        if event:
            self.append(event)
