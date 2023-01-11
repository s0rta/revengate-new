Loose ends and easy fixes
=========================

This is a list of loose ends, code optimization, and small tasks for the Godot implementation. None of those are blockers. If a task end up on the blocking path, it should end up in [roadmap.md]. 

## Developer Efficiency
- [ ] function to dump detailed status of all the actors on a board

## Strategies
- [ ] Tracking asserts that the target is on the same board
- [ ] Hero will sometimes move into an enemy while travelling

## Board
- [ ] inspect_tile() includes coord, pos, terrain, destination board for connectors
- [ ] Main.make_board() returns the builder
