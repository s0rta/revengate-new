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

from . import tender
from .engine import Engine
from .actors import Actor
from .loader import TopLevelLoader
from .maps import Map, Builder


def _split_factions(actors):
    factions = defaultdict(lambda: set())  # name->actors map
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

    winner = None
    duration = engine.current_turn - start
    for name in actors:
        if actors[name].is_alive:
            winner = name
    if debug:
        print("Battle is over!")
        print(f"{winner} won in {duration} turns!")
    return winner, duration


def run_many(combat_funct, nbtimes=100, ref_actor=None):
    """ Run a simulation nbtimes and print a statistical summary. """
    engine = tender.engine
    winners = Counter()
    durations = []
    
    for i in range(nbtimes):
        winner, duration = combat_funct(engine)
        durations.append(duration)
        winners[winner] += 1
    if ref_actor:
        champ = ref_actor
        victories = winners[ref_actor]
    else:
        champ, victories = winners.most_common(1)[0]
    pct = victories / nbtimes
    avg_turns = sum(durations) / len(durations)
    print(f"{champ:20} won {pct*100:5.1f}% of combats. "
          f"Fights lasted {avg_turns:4.1f} turns on average.")
    return pct, avg_turns


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
    parser.add_argument("-d", "--debug", action="store_true", 
                        help="Display debugging messages.")
    parser.add_argument("-n", "--nb-iter", type=int, default=100,  
                        help="Run simulation NB_ITER times [%(default)s].")
    parser.add_argument("--all", action="store_true", 
                        help=("Run the simulation on all actors in the file against "
                              "the first value supplied to --actors."))
    
    args = parser.parse_args()

    tender.loader = TopLevelLoader()
    for f in args.load:
        tender.loader.load(f)
        
    all_templates = list(tender.loader.templates())

    if args.map:
        tender.engine = Engine()
        map_demo(args.actors)
    elif args.all:
        for t_name in all_templates:
            if t_name == args.actors[0]:
                continue
            try:
                thing = tender.loader.invoke(t_name)
            except:
                print(f"can't simulate {t_name}")
                continue
            if not isinstance(thing, Actor):
                continue
            def sim(engine):
                tender.engine = Engine()
                return last_actor_standing(*[args.actors[0], t_name], debug=args.debug)
            run_many(sim, args.nb_iter, t_name)
    else:
        def sim(engine):
            tender.engine = Engine()
            return last_actor_standing(*args.actors, debug=args.debug)
        run_many(sim, args.nb_iter, args.actors[0])


if __name__ == '__main__':
    main()
