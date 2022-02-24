# Copyright © 2022 Yannick Gingras <ygingras@ygingras.net>

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

""" Conversations between actors. """

# TODO: placeholder for values like the hero's name


from .tags import Tag, t

import functools
import inspect


class SpeakerTag(Tag):
    pass


class ActionTag(Tag):
    pass


class DialogueElement:
    pass


class Line(DialogueElement):
    """ A line of dialogue. 
    
    If `after_ftag` is provided, it is called without arguments (except the global ones 
    described in the ActionMap class) immediately after the line is displayed. The 
    after_ftag is called everytime the line is spoked.
    """
    
    def __init__(self, text, speaker=None, after_ftag=None):
        super(Line, self).__init__()
        self.text = text
        self.speaker = speaker
        self.after_ftag = after_ftag
        
    def __str__(self):
        if self.speaker:
            return f'{self.speaker}: "{self.text}"'
        else:
            return self.text


class Action(DialogueElement):
    """ An event taking place sometime during the course of a dialogue. 
    
    If `after_ftag` is provided, it is called with the result of the current action 
    immediately after its execution. The other global arguments described in ActionMap 
    are supported.
    """

    def __init__(self, name, args, after_ftag=None):
        super(Action, self).__init__()
        self.name = name
        self.args = args
        self.after_ftag = after_ftag


class Dialogue:
    def __init__(self, key):
        self.key = key
        self.elems = []

    @property
    def sequence(self):
        # Writers out there might find this terminology easier to remember
        return self.elems
