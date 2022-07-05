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

""" Constants and other definitions used by the combat system """

from .tags import Tag

RES_FACTOR = 0.5  # 50% less damage if you have a resistance


class Family(Tag):
    """ Type of damage. """
    pass


class Families:
    IMPACT   = Family("impact")
    SLICE    = Family("slice")
    PIERCE   = Family("pierce")
    ARCANE   = Family("arcane")
    HEAT     = Family("heat")
    ACID     = Family("acid")
    POISON   = Family("poison")
    CHEMICAL = Family("chemical")
