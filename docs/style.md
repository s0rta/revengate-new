Revengate Style Guide
=====================

## coding conventions
* follow the GDScript style guidelines published by Godot
* max line length is 88

## common prefixes
* gen: generate, for things with a random component
* make: produce something that is going to be idempotent

## terminology
* when in doubt, name things after steam engine parts or concepts at the core of the industrial revolution
* board: a game level composed of multiple cells
* cell: one playable square on the game board
* coord: unless specified, the (x, y) coordinate of a cell, also `bpos` (for board pos),  noted "[x:y]"
* tile: one item of the TileSet, a cell has a tile, the same tile can be on multile cells.
* canvas: the pixel matrix that is displayed to the player
* position: unless specified, the (x, y), coordinate of a pixel or Node2D on the canvas, also `cpos` (for canvas pos). Godot consistently uses `position` for pixel and Node2D coordinates, noted "(x, y)"
* terrain: a group of tiles with common properties, like being walkable.
* hero: the player character, regardless of its gender
* actor: any character, includes monsters and hero
* h_delta: a health delta, the generic version of damage (<0) or healing (>0)
* ddump: debug dump – print a lot of info about an object to the termimal or to a file
* make_: prefix for deterministic generation
* gen_: prefix for pseudo-random procedural generation

## peridic actions and expiration
Mechanics that are invoked every turn should implement one of:
- start_turn(turn): called by the game loop, can skip turns if the item was away for a while, should be idempotent if called twice in a row with the same turn number;
- start_new_turn(): called by the game loop, once per turn.

The above are great place to compute the expiration of a component. Alternatively, mechanics can implement:
- decay(): called internally anytime during a turn.

Mechanics that have expired should `queue_free()` themselves and have `is_expired()` return true until they are garbage collected.

## colors
The UI color scheme is based on Material Design v2 with the primary colors from the splash screen. This too make is easy to get the sub colors:
https://m2.material.io/resources/color/

* primary: a13100
* primary-light: d9602f
* primary-dark: 6c0000
* secondary: d0943b
* secondary-light: ffc46a
* secondary-dark: 9b6605
* background: 231a00
* outline: 85736e

This tool derives beautiful MD3 color schemes, but it's still fairly buggy:
https://m3.material.io/theme-builder
