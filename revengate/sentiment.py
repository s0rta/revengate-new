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

""" Representation of how actors feel about other actors. """

from collections import defaultdict 

from .tags import t


class SentimentChart:
    """ Main sentiment representation between factions. """

    def __init__(self, mutual_pos=None, mutual_neg=None):
        self._chart = defaultdict(dict)  # me -> other -> sentiment in [-1..1]

        # TODO: make the loader to tag expansion inside nested lists so we don't have to 
        # do late validation with t()
        if mutual_pos:
            for a, b in mutual_pos:
                a, b = t(a), t(b)
                self._chart[a][b] = 1
                self._chart[b][a] = 1
            
        if mutual_neg:
            for a, b in mutual_neg:
                a, b = t(a), t(b)
                self._chart[a][b] = -1
                self._chart[b][a] = -1
        
    def sentiment(self, me, other):
        if me in self._chart:
            if other in self._chart[me]:
                return self._chart[me][other]

        return 0  # neutral by default        
