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

""" Items and inventory. """

from .effects import EffectVector
from .events import ItemUsage, PotentItemUsage


class Item:
    """ Something that can be picked up and dropped. """

    def __init__(self, name, weight, char='🛠️', verb="used", consumable=False):
        self.name = name
        self.weight = weight
        self.char = char
        self.verb = verb
        self.consumable = consumable  # disappears after being used
        self.is_consumed = False

    def __str__(self):
        return self.name
    
    def use(self, user, voluntary):
        """ Use the item, activate its effect on the user, return StatusEvent(s) 
        representing the action.
        """
        if self.consumable:
            self.is_consumed = True
        return [ItemUsage(user, self, voluntary)]


class PotentItem(Item, EffectVector):
    """ An Item that can carry effects when used. """
    
    def __init__(self, name, h_delta, family, weight):
        Item.__init__(self, name, weight)
        EffectVector.__init__(self, name, h_delta, family)

    def use(self, user, voluntary):
        _ = super().use(user, voluntary)
        return [PotentItemUsage(user, self, voluntary)]


class ItemCollection:
    """ A group of Items. """

    def __init__(self, *items):
        super(ItemCollection, self).__init__()
        self.items = list(items)

    def __bool__(self):
        return bool(self.items)
    
    def __iter__(self):
        return iter(self.items)

    def __getitem__(self, idx):
        return self.items[idx]
    
    def append(self, item):
        assert isinstance(item, Item)
        self.items.append(item)
        
    def remove(self, item):
        del self.items[self.items.index(item)]
        
    def pop(self):
        """ Return the item at the top of the stack and stop tracking it. """
        return self.items.pop()
    
    def top(self):
        """ Return the item at the top of the stack without removing it. """
        if self.items:
            return self.items[-1]
        else:
            return None
    
    def weight(self):
        return sum([i.weight for i in self.items])
    
    @property
    def char(self):
        if self.items:
            return self.items[-1].char
        else:
            return None


class ItemsSlot:
    """ 
    A placeholder for Items.

    This is using the descriptor protocol and should be set as a class 
    attribute.
    """
    
    def __init__(self):
        self.slot = None

    def __set_name__(self, owner, name):
        self.slot = '_' + name

    def __get__(self, obj, objtype=None):
        return getattr(obj, self.slot)

    def __set__(self, obj, items):
        if getattr(obj, self.slot, None):
            raise RuntimeError("Attempt to a replace a non-empty inventory.")
        if isinstance(items, list):
            items = ItemCollection(*items)
        setattr(obj, self.slot, items)
