Revengate Godot Roadmap
=======================

Major parts required to make the Godot implementation of Revengate a playable game.

## Minimum Viable Game (v0.2)

Builder:
- [x] spiral.next()
- [x] place monsters
- [x] dijkstra metrics to find the best spot for stairs

Combat:
- [x] rng.normal_dist(): built-in
- [x] 3 core stats, exported in the Godot UI
- [x] 2 rolls attack: to-hit, damage
- [x] attack result is immediately visible

Actor:
- [x] keep track of distination while moving
- [x] feed dest into Board.index

Dungeon:
- [x] link existing levels to newly created ones

UI:
- [x] start screen
- [ ] pinch to zoom
- [x] hero health points
- [x] game over screen

## v0.4
- [ ] items for progression
- [ ] damage over time
- [ ] extra stat for evasion
- [ ] victory conditions
- [ ] release to Google Play

Builder:
- [ ] mazes can fill arbitrary areas of a board

UI:
- [ ] credits screen
- [x] privacy screen


## v0.5
- [ ] narrations
- [ ] dialogues
- [ ] merge git repo with Revengate v0.1
- [ ] bestiary
- [ ] finely tuned animation over laps
- [ ] release on F-Droid

## v0.6
- [ ] style UI with Godot theme

## v1.0
- [ ] saved games
- [ ] Lyon overworld
