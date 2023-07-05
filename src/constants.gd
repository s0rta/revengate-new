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

const VERSION := "0.8.1"
const DEBUG = true

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

## Factions pre-define many of the allegiances and animosities
enum Factions {
	NONE,
	LUX_CO,
	BEASTS, 
	OUTLAWS
}

enum SkillLevel {
	NEOPHYTE,  # no skills at all
	INITIATE, 
	PROFICIENT, 
	EXPERT, 
	MYTHICAL,  # beyond the realm of mortals
}

const CORE_STATS := ["agility", "strength", "intelligence", "perception", "mana_burn_rate"] 
const SKILLS := ["evasion", "innate_attack", "fencing", "channeling", "device_of_focusing"]
# TODO: should be a const, but the parser has issue with the `+` expression
var CHALLENGES := [] + SKILLS

# Increments for world locations
const LOC_HIGHER = Vector3i(0, 0, 1)
const LOC_LOWER = Vector3i(0, 0, -1)
const LOC_NORTH = Vector3i(0, -1, 0)
const LOC_SOUTH = Vector3i(0, 1, 0)
const LOC_EAST = Vector3i(1, 0, 0)
const LOC_WEST = Vector3i(-1, 0 ,0)
const LOC_INVALID = Vector3i(256, 256, 256)

# Board Regions
const REG_CENTER = Vector2i.ZERO
const REG_NORTH = Vector2i(0, -1)
const REG_SOUTH = Vector2i(0, 1)
const REG_EAST = Vector2i(1, 0)
const REG_WEST = Vector2i(-1, 0)
const REGION_CHARS = {"C": REG_CENTER, 
						"N": REG_NORTH, 
						"S": REG_SOUTH, 
						"E": REG_EAST, 
						"W": REG_WEST}
const ALL_REGIONS = [REG_NORTH, REG_SOUTH, REG_EAST, REG_WEST, REG_CENTER]

# Animations and VFX
const FADE_DURATION := .15
const FADE_MODULATE := Color(.7, .7, .7, 0.0)
const VIS_MODULATE := Color.WHITE

const TAGS = ["silver", "ethereal", "undead", "gift", "broken", "lit", 
			"booze",
			# spells
			"vital-assemblage", "summoning", 
			# locks
			"key-blue", "key-red",
			# campaigns
			"quest-item", "quest-boss-retznac",
			]
