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

""" On screen messages and related utilities """

from time import time
from . import tender 


class Message:
    def __init__(self, text, turn, ts, mood=None, tags=None):
        self.text = text
        self.turn = turn
        self.ts = ts  # Unix timestamp
        self.mood = mood
        if tags is None:
            self.tags = ()
        else:
            self.tags = tags


class MessageStore:
    def __init__(self):
        self.messages = []
        self.seen_moods = set()

    def append(self, msg, mood=None, tags=None):
        if isinstance(msg, str):
            if tender.engine:
                turn = tender.engine.current_turn
            else:
                turn = None
            ts = time()
            msg = Message(msg, turn, ts, mood, tags)
        self.messages.append(msg)

    def is_relevant(self, mood):
        return mood not in self.seen_moods
        
