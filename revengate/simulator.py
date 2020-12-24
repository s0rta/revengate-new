# Copyright © 2020 Yannick Gingras <ygingras@ygingras.net>

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

""" Run simulations on various parts of the rule engine to test the balance. """

import sys
from collections import Counter
from pprint import pprint

from .tags import t
from .actors import Humanoid, Monster
from . import weapons
from .weapons import Events
from .loader import Loader

class Engine(object):
    """ Keep track of all the actors and implement the turns logic. """
    def __init__(self, loader):
        super(Engine, self).__init__()
        self.actors = [] # TODO: move to a priority queue when implementing initiative
        self.current_turn = 0
        self.loader = loader

    def register(self, actor):
        """ Register an actor with this engine. """
        actor.set_engine(self)
        self.actors.append(actor)

    def advance_turn(self):
        """ Update everything that needs to be updated at the start of a new 
        turn. """
        self.current_turn += 1
        events = Events()
        for actor in self.actors:
            events += actor.update()
        return events

def man_vs_wolf(engine):
    start = engine.current_turn
    me = engine.loader.invoke("hero")
    wolf = engine.loader.invoke("wolf")

    engine.register(me)
    engine.register(wolf)
    # FIXME: deregister after the combat

    while (me.health > 0 and wolf.health > 0):
        print(engine.advance_turn() or "no turn updates")
        hits = me.attack(wolf)
        print(hits or f"{me} miss!")
        hits = wolf.attack(me)
        print(hits or f"{wolf} miss!")
    duration = engine.current_turn - start
    victim = me.health <= 0 and me or wolf
    winner = victim is me and wolf or me
    print(f"{victim} died!  ({me.health} vs {wolf.health} HP;"
          f" {duration} turns)")
    return winner, duration


def mage_vs_wolf(engine):
    start = engine.current_turn
    me = engine.loader.invoke("mage")
    wolf = engine.loader.invoke("wolf")

    engine.register(me)
    engine.register(wolf)
    # FIXME: deregister after the combat

    while (me.health > 0 and wolf.health > 0):
        print(engine.advance_turn() or "no turn updates")
        if me.mana > 5:
            hits = me.cast(me.spells[0], wolf)
        else:
            hits = me.attack(wolf)
        print(hits or f"{me} miss!")
        hits = wolf.attack(me)
        print(hits or f"{wolf} miss!")
    duration = engine.current_turn - start
    victim = me.health <= 0 and me or wolf
    winner = victim is me and wolf or me
    print(f"{victim} died!  ({me.health} vs {wolf.health} HP;"
          f" {duration} turns)")
    return winner, duration


def run_many(engine, combat_func, nbtimes=100):
    """ Run a simulation nbtimes and print a statistical summary. """
    winners = Counter()
    durations = []
    
    for i in range(nbtimes):
        winner, duration = combat_func(engine)
        durations.append(duration)
        winners[winner.name] += 1
    champ, victories = winners.most_common(1)[0]
    avg = sum(durations) / len(durations)
    print(f"{champ} won {victories} times. "
          f"Fights lasted {avg} turns on average.")

def main():
    print("Running a simulation for basic attacks.")

    loader = Loader()
    loader.load(open(sys.argv[1], "r"))
    eng = Engine(loader)

    #man_vs_wolf(eng)
    run_many(eng, mage_vs_wolf)

if __name__ == '__main__':
    main()
