# Copyright © 2022–2024 Yannick Gingras <ygingras@ygingras.net> and contributors

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

const VERSION := "0.12.2"
const VERSION_CODE := 1028122
const DEBUG = true

const SAVE_PROB := 0.05  # chance that we save the game at the end of a turn

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
	CHEMICAL, 
	ELECTRIC, 
	MICROBIAL
}

## Factions pre-define many of the allegiances and animosities
enum Factions {
	NONE,
	LUX_CO,
	BEASTS, 
	OUTLAWS, 
	CIRCUS,
	CELESTIALS
}

enum SkillLevel {
	NEOPHYTE,  # no skills at all
	INITIATE, 
	PROFICIENT, 
	EXPERT, 
	MYTHICAL,  # beyond the realm of mortals
}

enum MessageLevels {
	INFO,  # regular game progress
	WARNING,  # you should probably change your strategy after seeing this
	CRITICAL  # you could die within 5 turns
}

enum TextSizes {
	UNSET,
	NORMAL, 
	BIG, 
	HUGE
}

const CORE_STATS := ["agility", "strength", "intelligence", "perception", 
					"health_full", "healing_prob", 
					"mana_burn_rate", "mana_recovery_prob"] 
const SKILLS := ["evasion", "innate_attack", "fencing", "channeling", "device_of_focusing", "polearm"]
# TODO: should be a const, but the parser has issue with the `+` expression
var CHALLENGES := [] + SKILLS

const ITEM_BASE_STATS := ["consumable", "switchable"]
var WEAPON_BASE_STATS := ["damage", "range", "damage_family"] + ITEM_BASE_STATS

const PERFECT_PERCEPTION = 75
const GREAT_PERCEPTION = 60
const INEPT_PERCEPTION = 20

const COORD_INVALID = Vector2i(-1, -1)

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
const REGION_NAMES = {"center": REG_CENTER, 
						"north": REG_NORTH, 
						"south": REG_SOUTH, 
						"east": REG_EAST, 
						"west": REG_WEST}
const ALL_REGIONS = [REG_NORTH, REG_SOUTH, REG_EAST, REG_WEST, REG_CENTER]

const CONVO_RANGE = 2

# Animations and VFX
const FADE_DURATION := .15
const FADE_MODULATE := Color(.7, .7, .7, 0.0)
const VIS_MODULATE := Color.WHITE

# Tags must be declared here before the can be added to items and actors. 
# This is a small safeguard against typos.
const TAGS = ["ethereal", "undead", "gift", "fragile", "broken", "lit", 
			"booze", 
			"magical",  # magical effects and items are often more potent
			"groupable",  # shows in "stacks" on the inventory screen
			# spells
			"vital-assemblage", "summoning", "healing", "attack",
			# locks
			"key-blue", "key-red",
			# campaigns
			"quest-item", "quest-reward", "quest-boss-retznac", "quest-boss-salapou",
			# weapons
			"silver", "throwable", 
			# messages
			"strategy",
			# progen placement constraints
			"spawn-north", "spawn-south", "spawn-west", "spawn-east", 
			"spawn-center", "spawn-distant", 
			# quest IDs
			"quest-lost-cards", "quest-stop-accountant", "quest-face-retznac",
			]

const OFFENSIVE_EVENTS:Array[String] = ["was_attacked", "was_insulted", "was_threatened", "was_targeted"]
