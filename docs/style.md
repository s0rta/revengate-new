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
* coord: unless specified, the (x, y) coordinate of a cell, also `bpos` (for board pos)
* tile: one item of the TileSet, a cell has a tile, the same tile can be on multile cells.
* canvas: the pixel matrix that is displayed to the player
* position: unless specified, the (x, y), coordinate of a pixel or Node2D on the canvas, also `cpos` (for canvas pos). Godot consistently uses `position` for pixel and Node2D coordinates.
* terrain: a group of tiles with common properties, like being walkable.
* hero: the player character, regardless of its gender
* actor: any character, includes monsters and hero

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
