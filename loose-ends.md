Loose ends and easy fixes
=========================

This is a list of loose ends, code optimization, and small tasks for the Godot implementation. None of those are blockers. If a task end up on the blocking path, it should end up in [roadmap.md]. 

## Developer Efficiency
- [ ] function to dump detailed status of all the actors on a board
- [ ] factor out the common boiler plate from cheats and gesture `start_` methods

## Combat
- [ ] over healing should slowly revert back to normal max health
  - [ ] the UI feedback should make it clear that the reverting is not an injury
- [ ] Effects can have dynamic `stats_modifiers` that change from turn to turn
- [ ] items expose `start_turn(turn)` rather than `start_new_turn()` in order to do early exits

## Strategies
- [ ] Tracking asserts that the target is on the same board
- [x] Hero will sometimes move into an enemy while travelling
- [ ] Travelling should ignore conditions

## Board
- [ ] inspect_tile() includes coord, pos, terrain, destination board for connectors
- [ ] Main.make_board() returns the builder
- [ ] BoadBuilder keeps and maintain an index

## Main
- [ ] Main sets the board on the turn queue, starts the turns in Main._ready()

## UI
- [ ] damage over time should have a different animation than attack damage
- [ ] message screen button should flash when new messages are added, rate limited to avoid the strobe effect
- [ ] a `ViewPanner` might be a more gesture-aware way to move the camera around; ref.: https://github.com/godotengine/godot/pull/71685
