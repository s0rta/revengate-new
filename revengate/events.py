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


from . import tender


def not_none(val):
    return val is not None


def is_action(event):
    """ Return whether event (or Events) counts as a turn action. """
    return isinstance(event, (list, StatusEvent)) and bool(event)


def is_move(event):
    """ Return whether event (or Events) includes an in-map movement. 
    
    Following a map-connector to a different map is not counted as a move.
    """
    if isinstance(event, list):
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
        # We only store the actor id rather than a strong ref to make StatusEvent pickle 
        # nicer.
        self.actor_id = actor and actor.id or None
        self.actor_stats = actor and actor.stats() or {}

        # Everyone who is involved with an event. Subclasses should append to this.
        if actor:
            self.actor_ids = [actor.id]
        else:
            self.actor_ids = []

        # This is cached at creation time because the actor might not be available 
        # anymore by the time we need to display the message.
        self.summary_str = self.summary()
        
    def __bool__(self):
        return self.cost > 0

    def __str__(self):
        return self.summary_str

    def _actor_by_id(self, actor_id):
        if tender.engine and self.actor_id:
            return tender.engine.actor_by_id(actor_id)
        else:
            return None
    
    @property
    def actor(self):
        return self._actor_by_id(self.actor_id)

    def summary(self):
        """ Return a summary of the event that is fit for showing directly to the 
        player. Perception is taken into account.
        
        Sub-classes should override this. """
        return repr(self)

    def details(self):
        """ Return a summary of the event that is fit debugging. 
        
        Sub-classes might have to override this. """
        return repr(self)


class Move(StatusEvent):
    """ The actor moved. """

    def __init__(self, performer, old_pos, new_pos):
        self.old_pos = old_pos
        self.new_pos = new_pos
        super().__init__(performer)
        
    def summary(self):
        return f"{self.actor} moved from {self.old_pos} to {self.new_pos}."

    @property
    def performer(self):
        return self.actor


class Teleport(Move):
    """ The actor materialized somewhere else (not an action). """
    cost = 1
    
    def __init__(self, performer, old_pos, new_pos):
        super().__init__(performer, old_pos, new_pos)
        
    def summary(self):
        return f"{self.actor} teleported from {self.old_pos} to {self.new_pos}."
    

class Narration(StatusEvent):
    # TODO: those should not cost an action
    pass


class Conversation(StatusEvent):
    def __init__(self, initiator, responder, dialogue_tag):
        self.responder_id = responder.id
        self.responder_stats = responder.stats()
        self.tag = dialogue_tag
        super().__init__(initiator)
        self.actor_ids.append(responder.id)
        
    def summary(self):
        return (f"{self.actor} had a chat with {self.responder} about {self.tag}.")
    
    @property
    def responder(self):
        return self._actor_by_id(self.responder_id)
    

class StairsEvent(StatusEvent):
    """ The actor took a flight of stairs. """

    def __init__(self, performer, from_pos):
        self.from_pos = from_pos
        super().__init__(performer)
        
    def summary(self):
        return f"{self.actor} followed stairs at {self.from_pos}."


class Rest(StatusEvent):
    """ The actor did nothing. """        

    def summary(self):
        return f"{self.actor} waits patiently."


class Death(StatusEvent):
    """ The actor died. """

    def __init__(self, victim):
        super().__init__(victim)
        
    def summary(self):
        return f"{self.actor_stats['str']} died!"


class HealthEvent(StatusEvent):
    """ The actor's health just got better or worse. """
    big_delta = .4  # as a fraction of full_health

    def __init__(self, actor, h_delta):
        self.h_delta = h_delta 
        super().__init__(actor)

    def _delta_to_adj(self, actor_stats):
        """ Return an adjective to describe how big a health delta is as perceived by 
        the hero. """
        if tender.hero:
            percent = abs(self.h_delta) / (actor_stats["full_health"] * self.big_delta)
            return tender.hero.vague_desc(self.h_delta, percent)
        else: 
            return str(abs(self.h_delta))
        
    def summary(self):
        adj = self._delta_to_adj(self.actor_stats)
        if self.h_delta >= 0:
            return f"{self.actor} heals {adj} points."
        else:
            return (f"{self.actor} suffers {adj} damages from injuries.")
                        

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

    @property
    def victim_id(self):
        return self.actor_id

    @property
    def victim_stats(self):
        return self.actor_stats


class Hit(Injury):
    """ A successful hit with a weapon. """

    def __init__(self, attacker, victim, weapon, damage, critical=False):
        self.attacker_id = attacker.id
        self.attacker_stats = attacker.stats()
        self.weapon = weapon
        self.critical = critical
        super().__init__(victim, damage)
        self.actor_ids.append(attacker.id)
        
    def summary(self):
        adj = self._delta_to_adj(self.victim_stats)
        s = (f"{self.attacker} hit {self.victim_stats['str']} with a {self.weapon}"
             f" for {adj} damages!")
        if self.critical:
            s += " Critical hit!"
        return s

    @property
    def attacker(self):
        return self._actor_by_id(self.attacker_id)


class Miss(StatusEvent):
    """ Tried to attack, but didn't make contact with the target. """

    def __init__(self, attacker, target, weapon):
        self.target_id = target.id
        self.target_stats = target.stats()
        self.weapon = weapon
        super().__init__(attacker)
        self.actor_ids.append(target.id)
        
    def summary(self):
        return f"{self.actor} misses {self.target}."

    @property
    def target(self):
        return self._actor_by_id(self.target_id)


class Yell(StatusEvent):
    """ Yell something in no particular direction. """
    
    def __init__(self, actor, msg):
        self.msg = msg
        super().__init__(actor)
        
    def summary(self):
        return f"{self.actor} yells {self.msg}."


class InventoryChange(StatusEvent):
    """ Added or lossed something form the inventory """

    def __init__(self, actor, item):
        self.item = item
        super().__init__(actor)
        
    def summary(self):
        return f"{self.item} changed possession."


class Pickup(InventoryChange):
    """ Picked something from the ground """

    def __init__(self, actor, item):
        super().__init__(actor, item)
        
    def summary(self):
        return f"Picked {self.item} from the ground."


class Events(list):
    """ A group of StatusEvents.  None-events are implicitly ignored. """
    
    def __init__(self, *events):
        if len(events) >= 1 and isinstance(events[0], list):
            raise ValueError("Nesting Events is unsuported. Did you mean do "
                             "call Events(*events) instead?")
        if events:
            events = filter(not_none, events)
            super(Events, self).__init__(events)
        else:
            super(Events, self).__init__()
        
    def __str__(self):
        return " ".join(map(str, self))

    def __iadd__(self, other):
        if other:
            other = filter(not_none, other)
            return super(Events, self).__iadd__(other)
        else:
            return self
    
    def add(self, event):
        if isinstance(event, list):
            raise ValueError("Nesting Events is unsuported. Did you mean do "
                             "call `events += other_events` instead?")
        if event is not None:
            self.append(event)
