#! /usr/bin/env python3

# Copyright © 2020–2022 Yannick Gingras <ygingras@ygingras.net> and contributors

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
import itertools
from collections import Counter, defaultdict
from pprint import pprint
from argparse import ArgumentParser

from .engine import Engine
from .tags import t
from .actors import Humanoid, Monster
from . import weapons, tender
from .loader import TopLevelLoader
from .maps import Map, Builder, MapOverlay


def man_vs_wolf(engine):
    start = engine.current_turn
    me = tender.loader.invoke("hero")
    wolf = tender.loader.invoke("wolf")

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
    me = tender.loader.invoke("mage")
    wolf = tender.loader.invoke("wolf")

    engine.register(me)
    engine.register(wolf)
    # FIXME: deregister after the combat

    while (me.health > 0 and wolf.health > 0):
        print(engine.advance_turn() or "no turn updates")
        if me.mana > 5:
            hits = me.cast("fire-arc", wolf)
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

def _split_factions(actors):
    factions = defaultdict(lambda: set()) # name->actors map
    for a in actors:
        factions[a.faction].add(a)
    return factions

def last_faction_standing(engine, actor_names):
    start = engine.current_turn
    actors = set()

    def filter_empties():
        nonlocal actors
        for f in factions:
            factions[f] = {a for a in factions[f] if a.health > 0}
        actors = {a for a in actors if a.health > 0}

    for name in actor_names:
        actor = tender.loader.invoke(name)
        actors.add(actor)
        engine.register(actor)
    orig_cast = list(actors)
    factions = _split_factions(actors)

    while len([f for f in factions if len(factions[f]) > 0]) > 1:
        print(engine.advance_turn() or "no turn updates")
        filter_empties()
        for a in actors:
            if a.health <= 0:
                continue
            target = a.strategy.select_target(actors - {a})
            if target:
                hit = a.attack(target)
                print(hit)
                if target.health <= 0:
                    print(f"{target} died!")
        filter_empties()

    for actor in orig_cast:
        engine.deregister(actor)
    duration = engine.current_turn - start
    winner = [f for f in factions if len(factions[f]) > 0][0]
    print("Battle is over!")
    print(f"{winner.name} won in {duration} turns!")
    print("Survivors: " +
          ", ".join([f"{a.name} ({a.health}HP)" for a in factions[winner]]))
    return winner, duration


def wolf_pack_skirmish(engine):
    return last_faction_standing(engine, ["mage", "wolf", "wolf", "wolf"])


def run_many(engine, combat_funct, nbtimes=100):
    """ Run a simulation nbtimes and print a statistical summary. """
    winners = Counter()
    durations = []
    
    for i in range(nbtimes):
        winner, duration = combat_funct(engine)
        durations.append(duration)
        winners[winner.name] += 1
    champ, victories = winners.most_common(1)[0]
    avg = sum(durations) / len(durations)
    print(f"{champ} won {victories} times. "
          f"Fights lasted {avg} turns on average.")


def map_demo(eng, actor_names):
    map = Map()
    builder = Builder(map)
    builder.init(40, 20)
    builder.room((5, 5), (20, 15), True)
    builder.room((12, 7), (13, 12), True)
    eng.change_map(map)

    bag = eng.loader.invoke("bag")
    map.place(bag)
    
    actors = set()
    for name in actor_names:
        a = eng.loader.invoke(name)
        actors.add(a)
        map.place(a)
        eng.register(a)
    factions = _split_factions(actors)
    orig_cast = list(actors)

    def filter_empties():
        # TODO: find a more graceful way to handle death
        nonlocal actors
        for f in factions:
            factions[f] = {a for a in factions[f] if a.health > 0}
        actors = {a for a in actors if a.health > 0}
    
    start = eng.current_turn
    while len([f for f in factions if len(factions[f]) > 0]) > 1:
        print(eng.advance_turn() or "no turn updates")
        filter_empties()
        for a in actors:
            if a.health <= 0:
                continue
            event = a.act(map)
            if event:
                print(event)
        filter_empties()
        print(map.to_text())
    
    eng.change_map(None)
    duration = eng.current_turn - start
    winner = [f for f in factions if len(factions[f]) > 0][0]
    print("Battle is over!")
    print(f"{winner.name} won in {duration} turns!")
    print("Survivors: " +
          ", ".join([f"{a.name} ({a.health}HP)" for a in factions[winner]]))
    return winner, duration


def main():
    parser = ArgumentParser()
    parser.add_argument("-l", "--load", metavar="FILE", type=open, nargs="+", 
                        help="Template files to load.")
    parser.add_argument("-a", "--actors", metavar="ACTOR", type=str, nargs="+", 
                        help=("Actors to include in the simulation; names can " 
                              "be repeated to create a group of the same kind " 
                              "of actor."))
    parser.add_argument("-m", "--map", action="store_true", 
                        help="Run the map simulation instead of the combat one.")
    
    args = parser.parse_args()

    tender.loader = TopLevelLoader()
    for f in args.load:
        tender.loader.load(f)
    eng = Engine()

    if args.map:
        map_demo(eng, args.actors)
    else:
        def sim(engine):
            return last_faction_standing(engine, args.actors)
        run_many(eng, sim)


if __name__ == '__main__':
    main()
