# Copyright © 2020-2022 Yannick Gingras <ygingras@ygingras.net> and contributors

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


def is_move(event):
    """ Return whether event (or Events) includes an in-map movement. 
    
    Following a map-connector to a different map is not counted as a move.
    """
    if isinstance(event, Events):
        for evt in event:
            if isinstance(evt, Move) and bool(evt):
                return True
    elif isinstance(event, Move) and bool(event):
        return True
    return False
        

def iter_events(events):
    if isinstance(events, StatusEvent):
        return iter((events,))
    else:
        return iter(events)


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

    cost = 1
    
    def __init__(self, actor):
        super(StatusEvent, self).__init__()
        self.actor = actor

    def __bool__(self):
        return self.cost > 0


class Move(StatusEvent):
    """ The actor moved. """
    def __init__(self, performer, old_pos, new_pos):
        super().__init__(performer)
        self.old_pos = old_pos
        self.new_pos = new_pos
        
    def __str__(self):
        return f"{self.actor} moved from {self.old_pos} to {self.new_pos}."


class Teleport(Move):
    """ The actor materialized somewhere else (not an action). """
    cost = 1
    
    def __init__(self, performer, old_pos, new_pos):
        super().__init__(performer, old_pos, new_pos)
        
    def __str__(self):
        return f"{self.actor} teleported from {self.old_pos} to {self.new_pos}."
    

class Narration(StatusEvent):
    # TODO: those should not cost an action
    pass


class Conversation(StatusEvent):
    def __init__(self, initiator, responder, dialogue_tag):
        super().__init__(initiator)
        self.responder = responder
        self.tag = dialogue_tag
        
    def __str__(self):
        return (f"{self.actor} had a chat with {self.responder} about {self.tag}.")
    

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
