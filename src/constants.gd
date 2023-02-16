# Copyright © 2022–2023 Yannick Gingras <ygingras@ygingras.net> and contributors

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

## Various game constants that are used across scenes.
## This script is autoloaded at `Consts`
extends Node

const VERSION := "0.3.9"

## The kind of damage, mostly used to compute resistances. Can apply to healing as well.
enum DamageFamily {
	NONE,
	IMPACT, 
	SLICE, 
	PIERCE, 
	ARCANE, 
	HEAT, 
	ACID, 
	POISON, 
	CHEMICAL
}

enum SkillLevel {
	NEOPHYTE,  # no skills at all
	INITIATE, 
	PROFICIENT, 
	EXPERT, 
	MYTHICAL,  # beyon the realm of mortals
}

const CORE_STATS := ["agility", "strength"] 
const SKILLS := ["evasion", "innate_attack", "fencing"]
# TODO: should be a const, but the parser has issue with the `+` expression
var CHALLENGES := [] + SKILLS
