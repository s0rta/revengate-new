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

from .actors import Humanoid, Monster
from . import weapons

def main():
    print("Running a simulation for basic attacks.")
    me = Humanoid(60, 0, .50, .50, .50, 4, 4)
    me.name = "you"
    wolf = Monster(30, 0, .35, .55)
    wolf.weapon = weapons.Injurious("bite", 5, weapons.DmgType.PIERCE)
    wolf.resistances[weapons.DmgType.IMPACT] = 1

    while (me.health > 0 and wolf.health > 0):
        hits = me.attack(wolf)
        print(hits or f"{me} miss!")
        hits = wolf.attack(me)
        print(hits or f"{wolf} miss!")
    victim = me.health <= 0 and me or wolf
    print(f"{victim} died!  ({me.health} vs {wolf.health} HP)")

if __name__ == '__main__':
    main()
