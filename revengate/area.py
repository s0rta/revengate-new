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

""" Collections of related maps, such as a dungeon. """

from collections import defaultdict
from uuid import uuid4

from .maps import Map


class Area:
    def __init__(self):
        self.id = str(uuid4())
        self.maps = {}
        self.start = None  # id of the first map in this area
        self._depths = defaultdict(int)

    def __getitem__(self, mapid):
        return self.maps[mapid]

    def add_map(self, map, parent=None):
        if isinstance(parent, str):
            parent = self.maps[parent]
        self.maps[map.id] = map
        self._depths[map.id] = self.depth(parent) + 1
        if parent is None and self.start is None:
            self.start = map.id

    def depth(self, map):
        if map is None:
            return 0
        else:
            return self._depths[map.id]

    def size(self):
        return len(self.maps)
