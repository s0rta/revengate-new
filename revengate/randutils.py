# Copyright © 2021 Yannick Gingras <ygingras@ygingras.net>

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

def rint(nmax):
    if isinstance(nmax, tuple):
        nmin, nmax = nmax
    else:
        nmin = 0
    return random.randint(nmin, nmax)

def dice(nsides):
    return random.randint(1, nsides)

d = dice

def r_success_test(success_rate):
    """ Return True success_rate percent of the time. 
    
    success_rate should be in 0..1 
    """
    return random.random() <= success_rate
rstest = r_success_test

def r_failure_test(failure_rate):
    """ Return False failure_rate percent of the time. 
    
    failure_rate should be in 0..1 
    """
    return random.random() > failure_rate
rftest = r_failure_test

def biased_choice(seq, bias, biased_elem=None):
    """ Select an element from seq with a bias for one of the element. 
    
    bias: how many times is the biased element more likely to be select 
    ex.: 0.5 for half as likely, 2 for twice as likely 
    
    If biased_elem elem is provided and is present in the sequence, it's first 
    occurence will be biased; if it's not in the sequence, no item will receive 
    bias. If biased_elem is not provided, the first element receives the bias. 
    """
    if biased_elem is not None:
        try:
            bias_idx = seq.index(biased_elem)
        except ValueError:
            bias_idx = None
    else:
        bias_idx = 0
    weights = [i==bias_idx and bias or 1 for i in range(len(seq))]
    return random.choices(seq, weights=weights)[0]

def rpop(seq):
    """ Select a random elememt from a sequence, return both the element and 
    the modified sequence without the selected element.
    
    Work on a copy of the sequence, the original is not modified. 
    """
    idx = random.randrange(len(seq))
    return seq[idx], seq[:idx] + seq[idx+1:]

def rstate_save(fname):
    """ Save the random generator state to a file. """
    state = random.getstate()
    open(fname, "w").write(json.dumps(state))

def rstate_restore(fname):
    """ Restore the random generator state from a file. """
    state = json.load(open(fname, "r"))
    state = state[:1] + [tuple(state[1])] + state[2:]
    random.setstate(state)
