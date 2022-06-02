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

class SentimentChart:
    """ Main sentiment representation between factions. """

    def __init__(self, mutual_pos=None, mutual_neg=None, 
                 onesided_pos=None, onesided_neg=None):
        """ mutual_X is a list of pairs
        onesided_X is a {"feeler": [targets...]} mapping """
        self._chart = defaultdict(dict)  # me -> other -> sentiment in [-1..1]

        if mutual_pos:
            for a, b in mutual_pos:
                self._chart[a][b] = 1
                self._chart[b][a] = 1
            
        if mutual_neg:
            for a, b in mutual_neg:
                self._chart[a][b] = -1
                self._chart[b][a] = -1
        
        if onesided_pos:
            for k, targets in onesided_pos.items():
                for target in targets:
                    self._chart[k][target] = 1

        if onesided_neg:
            for k, targets in onesided_neg.items():
                for target in targets:
                    self._chart[k][target] = -1
        
    def sentiment(self, me, other):
        if me in self._chart:
            if other in self._chart[me]:
                return self._chart[me][other]

        return 0  # neutral by default        
