#! /usr/bin/env python3

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

""" Generate and save pre-generated maps """

import os
import sys
import glob
import pickle
from argparse import ArgumentParser

from .randutils import rng
from .maps import Map, Builder
from .loader import DATA_DIR


def save_map(builder, num):
    fname = os.path.join(DATA_DIR, "maps", f"map-{num:04}.pickle")
    with open(fname, "wb") as f:
        pickle.dump(builder, f)


def mk_map(args):
    map = Map()
    builder = Builder(map)
    builder.init(140, 30)
    # builder.room(5, 5, 35, 15, True)
    nb_rooms = rng.randrange(3, 7)
    for i in range(nb_rooms):
        builder.random_room((5, 20), (5, 10))
    builder.maze_connect(debug=False)
    if len(builder.mazes) > 1:
        return None
    print(map.to_text(True))
    resp = input("Save this map (y/n)?").strip()
    if resp == "y":
        return builder
    else:
        return None


def last_map_num(args):
    maps_pat = os.path.join(DATA_DIR, "maps", "map-*.pickle")
    map_files = glob.glob(maps_pat)
    if map_files:
        map_files.sort()
        fname = os.path.splitext(map_files[-1])
        return int(fname.split("-")[-1])
    else: 
        return 0


def main():
    parser = ArgumentParser(sys.argv[0], description=__doc__)
    args = parser.parse_args()
    
    # find max current map no
    num = last_map_num(args)
    
    while True:
        builder = mk_map(args)
        if builder:
            num += 1
            save_map(builder, num)


if __name__ == "__main__":
    main()
