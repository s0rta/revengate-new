# Copyright © 2021–2022 Yannick Gingras <ygingras@ygingras.net>

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

""" Helper functions for random number generation and selections. """

import random
import json

# Global instance of the random number generator. This must be initialized 
# before we start using random numbers. This is separate from the build-in RNG 
# to make game logic self-contained and easier to reproduce.
rng = None


class RandomGenerator(random.Random):
    """ Like random.Random with few convenient utilities. """
    ...
    # TODO: move all the default functs in here.

    def state_save(self, fname):
        """ Save the random generator state to a file. """
        state = self.getstate()
        open(fname, "w").write(json.dumps(state))

    def state_restore(self, fname):
        """ Restore the random generator state from a file. """
        state = json.load(open(fname, "rt"))
        state = state[:1] + [tuple(state[1])] + state[2:]
        self.setstate(state)

    def rint(self, nmax):
        if isinstance(nmax, tuple):
            nmin, nmax = nmax
        else:
            nmin = 0
        return self.randint(nmin, nmax)

    def dice(self, nsides):
        return self.randint(1, nsides)

    d = dice

    def r_success_test(self, success_rate):
        """ Return True success_rate percent of the time. 
        
        success_rate should be in 0..1 
        """
        return self.random() <= success_rate
    rstest = r_success_test

    def r_failure_test(self, failure_rate):
        """ Return False failure_rate percent of the time. 
        
        failure_rate should be in 0..1 
        """
        return self.random() > failure_rate
    rftest = r_failure_test

    def biased_choice(self, seq, bias, biased_elem=None):
        """ Select an element from seq with a bias for one of the element. 
        
        bias: how many times is the biased element more likely to be select 
        ex.: 0.5 for half as likely, 2 for twice as likely 
        
        If biased_elem elem is provided and is present in the sequence, it's 
        first occurence will be biased; if it's not in the sequence, no item 
        will receive bias. If biased_elem is not provided, the first element 
        receives the bias. 
        """
        if biased_elem is not None:
            try:
                bias_idx = seq.index(biased_elem)
            except ValueError:
                bias_idx = None
        else:
            bias_idx = 0
        weights = [i==bias_idx and bias or 1 for i in range(len(seq))]
        return self.choices(seq, weights=weights)[0]

    def rpop(self, seq):
        """ Select a random elememt from a sequence, return both the element 
        and the modified sequence without the selected element.
        
        Work on a copy of the sequence, the original is not modified. 
        """
        idx = self.randrange(len(seq))
        return seq[idx], seq[:idx] + seq[idx+1:]

    def pos_in_rect(self, rect):
        """ Return a random position that is inside rect. 
        
        The perimeter of rect is included in the possible results. """
        (x1, y1), (x2, y2) = rect
        x, y = rng.randrange(x1, x2+1), rng.randrange(y1, y2+1)
        return (x, y)

rng = RandomGenerator()
