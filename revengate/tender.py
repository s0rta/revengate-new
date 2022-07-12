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

""" Global that must be kept accessible from many parts of the game. 

There are no guarantees on initialization. Whatever governor or simulation is setting 
things in motion must also make sure that this the required globals are initialized.
"""
# from .engine import Engine
from .ui import UI
# from .commands import CommandMap
# from .actors import Actor
# from .loader import TopLevelLoader
from .sentiment import SentimentChart

loader = None
engine = None
ui: UI = None
commands = None
hero = None
sentiments: SentimentChart = None
dungeon = None
messages = None
