Revengate Style Guide
=====================

## common prefixes
* gen: generate, for things with a random component
* make: produce something that is going to be idempotent

## terminology
* board: a game level composed of multiple cells
* cell: one playable square on the game board
* coord: unless specified, the (x, y) coordinate of a cell, also `bpos` (for board pos)
* tile: one item of the TileSet, a cell has a tile, the same tile can be on multile cells.
* canvas: the pixel matrix that is displayed to the player
* position: unless specified, the (x, y), coordinate of a pixel or Node2D on the canvas, also `cpos` (for canvas pos). Godot consistently uses `position` for pixel and Node2D coordinates.
* terrain: a group of tiles with common properties, like being walkable.
* hero: the player character, regardless of its gender
* actor: any character, includes monsters and hero
