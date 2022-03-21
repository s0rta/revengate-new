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

""" Items and inventory. """

class Item:
    """ Something that can be picked up and dropped. """
    def __init__(self, name, weight, char='🛠️'):
        self.name = name
        self.weight = weight
        self.char = char


class ItemCollection:
    """ A group of Items. """
    def __init__(self, *items):
        super(ItemCollection, self).__init__()
        self.items = list(items)

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
    
    def __bool__(self):
        return bool(self.items)
    
    def __iter__(self):
        return iter(self.items)
    
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
        super(ItemsSlot, self).__init__()
        self.slot = None

    def __set_name__(self, owner, name):
        self.slot = '_' + name

    def __get__(self, obj, objtype=None):
        return getattr(obj, self.slot)

    def __set__(self, obj, items):
        if isinstance(items, list):
            items = ItemCollection(*items)
        setattr(obj, self.slot, items)
