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

""" Politics, allegiances and mood """

from .randutils import rng
from . import tender

# ideas:
# - seen or other sense, ex.: 
# -- smell or felling of moisture
# -- feeling a magical aura / presence
# - awareness depends on your factions / abilities
# - does it impede your movement: ex: difficult, slippery, practically impassable
# - do not spam the player with things they know by now
# - can be represented as an item, potentially useful
# - possibly ephemeral / will fade away over time
# - possibly traps
# - morale and spiritual effects specific to various factions


class Mood: 
    """ Context information about a place that favours the immersion without obviously 
    influencing the game play. """
    material = False

    def __init__(self, desc, score=1):
        self.desc = desc
        self.score = score

    def __str__(self):
        return self.desc

    def __eq__(self, other):
        return self.desc == other.desc

    def __hash__(self):
        return hash(self.desc)

    def materialize(self):
        """ Convert the mood into something more concrete that can be placed on the map. 
        
        Callers should only only call this is self.material is True.
        """
        return NotImplementedError()


class MoodItem(Mood): 
    material = True

    def __init__(self, template_name, score=1):
        super().__init__(None, score)
        self.template_name = template_name.lstrip("*")

    def materialize(self):
        return tender.loader.invoke(self.template_name)


class Faction: 
    def __init__(self, name, tag_name):
        self.name = name
        self.tag_name = tag_name
        
        # list of (mood, weight) tuples:
        # - None is allowed, 
        # - same weight semantic as random.choices()
        self._moods = []  

    def add_mood(self, mood, weight=1, score=1):
        if isinstance(mood, str):
            if mood.startswith("*"):
                mood = MoodItem(mood, score)
            else:
                mood = Mood(mood, score)                
        self._moods.append((mood, weight))

    def gen_moods(self):
        """ Return a collection of moods associated with the faction.
        
        Return None if the faction has no mood. 
        """
        return [mood for mood, weight in self._moods]
    
    def gen_mood(self):
        """ Return a (mood, score) tuple for the faction. 
        
        The probability of getting any specific mood is adjusted. 

        Return None if there are no moods associated with the faction or if all moods 
        have low probability of occurring.
        """
        if self._moods:
            mood = rng.weighted_choice(self._moods)
            if mood.material:
                return mood.materialize(), mood.score
            else:
                return mood, mood.score
        return None
