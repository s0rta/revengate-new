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
import itertools

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


def last_actor_standing(a, b, debug=False):
    engine = tender.engine
    start = engine.current_turn
    actors = {a: tender.loader.invoke(a),
              b: tender.loader.invoke(b)}
    
    engine.register(actors[a])
    engine.register(actors[b])

    while actors[a].is_alive and actors[b].is_alive:
        for attacker, victim in itertools.permutations(actors.values(), 2):
            hit = attacker.attack(victim)
            if debug:
                print(hit)
            if victim.is_dead:
                if debug:
                    print(f"{victim} died!")
                break
        turn_updates = engine.advance_turn()
        if debug:
            print(turn_updates or "no turn updates")

    name = None
    duration = engine.current_turn - start
    for name in actors:
        if actors[name].is_alive:
            winner = name
    if debug:
        print("Battle is over!")
        print(f"{winner} won in {duration} turns!")
    return winner, duration


def wolf_pack_skirmish(engine):
    return last_faction_standing(engine, ["mage", "wolf", "wolf", "wolf"])


def run_many(combat_funct, nbtimes=100):
    """ Run a simulation nbtimes and print a statistical summary. """
    engine = tender.engine
    winners = Counter()
    durations = []
    
    for i in range(nbtimes):
        winner, duration = combat_funct(engine)
        durations.append(duration)
        winners[winner] += 1
    champ, victories = winners.most_common(1)[0]
    avg = sum(durations) / len(durations)
    print(f"{champ} won {victories} times. "
          f"Fights lasted {avg} turns on average.")


def map_demo(actor_names):
    eng = tender.engine
    map = Map()
    builder = Builder(map)
    builder.init(40, 20)
    builder.room((5, 5), (20, 15), True)
    builder.room((12, 7), (13, 12), True)
    eng.change_map(map)

    bag = tender.loader.invoke("pen")
    map.place(bag)
    
    actors = set()
    for name in actor_names:
        a = tender.loader.invoke(name)
        actors.add(a)
        map.place(a)
    factions = _split_factions(actors)

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
            event = a.act()
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

    if args.map:
        tender.engine = Engine()
        map_demo(args.actors)
    else:
        def sim(engine):
            tender.engine = Engine()
            return last_actor_standing(*args.actors)
        run_many(sim)


if __name__ == '__main__':
    main()
