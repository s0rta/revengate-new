Loose ends and easy fixes
=========================

This is a list of loose ends, code optimization, and small tasks for the Godot implementation. None of those are blockers. If a task end up on the blocking path, it should end up in [roadmap.md]. 

## Developer Efficiency
- [ ] function to dump detailed status of all the actors on a board

## Combat
- [ ] over healing should slowly revert back to normal max health
  - [ ] the UI feedback should make it clear that the reverting is not an injury

## Strategies
- [ ] Tracking asserts that the target is on the same board
- [ ] Hero will sometimes move into an enemy while travelling
- [ ] Travelling should ignore conditions

## Board
- [ ] inspect_tile() includes coord, pos, terrain, destination board for connectors
- [ ] Main.make_board() returns the builder
- [ ] BoadBuilder keeps and maintain an index

## Main
- [ ] Main sets the board on the turn queue, starts the turns in Main._ready()

## UI
- [ ] damage over time should have a different animation than attack damage
