#!/usr/bin/env python3

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


import sys
from argparse import ArgumentParser

from . import __version__, __doc__

def main():
    parser = ArgumentParser(sys.argv[0], description=__doc__)
    parser.add_argument("--version", action="store_true", 
                        help="Print version and exit.")
    args = parser.parse_args()
    
    if args.version:
        print(f"Revengate version {__version__}")
        sys.exit(0)

    print("Boiler pressure: maximum!")

if __name__ == "__main__":
    main()
