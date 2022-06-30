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


import pytest

from revengate.events import Events, Injury, Move


def test_event_iter():
    """ Test that we can access all individual events by using the iterator protocol. 
    """
    events = Events(Injury(None, 25), Injury(None, 10))
    events.add(Move(None, (0, 0), (1, 1)))
    for i, event in enumerate(events):
        assert isinstance(event, ()) is not None
    assert i == 2

    
def test_no_nesting():
    """ Test that nested Events collections are dissallowed """
    
    top_events = Events(Move(None, (0, 0), (1, 1)), Move(None, (1, 1), (2, 1)))
    sub_events = Events(Injury(None, 10)) 

    with pytest.raises(ValueError):
        top_events.add(sub_events)
    
    with pytest.raises(ValueError):
        Events(sub_events)
        
        
def test_filter_none_and_emtpy():
    assert not Events(None, None)
    assert not Events(*[])
    assert not Events(*[None, None])
    events = Events()
    events.add(None)
    assert not events
    events += [None]
    assert not events
    assert len(Events(None, None, Injury(None, 10))) == 1
