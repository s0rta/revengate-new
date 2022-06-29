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

""" Weapons logic and common weapon types. """


from .items import Item
from .effects import EffectVector, Injurious


class Weapon(Item, Injurious):
    """ An actual weapon.  Something that takes inventory space and must be 
    weilded. """

    def __init__(self, name, damage, family, weight, char='⚔️', verb=None):
        Item.__init__(self, name, weight, char)
        Injurious.__init__(self, name, damage, family, verb)

    def __str__(self):
        return self.name


class Spell(EffectVector):
    """ A magical invocation """

    def __init__(self, name, h_delta, family, cost, verb=None):
        super(Spell, self).__init__(name, h_delta, family, verb)
        self.cost = cost
        
