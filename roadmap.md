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
- [x] button to follow stairs
- [x] start screen
- [x] screen widget to zoom
- [x] hero health points
- [x] game over screen
- [x] welcome message on first game startup

## v0.4
- [ ] victory conditions
- [x] release to Google Play
- [ ] cheat codes

Combat:
- [ ] new evasion stat to increase all to-hit rolls
- [ ] items for progression
- [ ] damage over time

Builder:
- [ ] mazes can fill arbitrary areas of a board

UI:
- [ ] all contributors on credits screen
- [ ] bug: cliking on dark area crashes the game
- [ ] visual feedback for when inputs are accepted
- [ ] inventory screen
- [ ] gesture to access non-default actions, like following stairs see [docs/gestures.md]
- [ ] pinch to zoom
- [x] privacy screen


## v0.5
- [x] merge git repo with Revengate v0.1
- [ ] release on F-Droid

UI: 
- [ ] narrations
- [ ] dialogues
- [ ] bestiary
- [ ] finely tuned animation overlaps
- [ ] messages pane
- [ ] messages history screen

## v0.6
- [ ] style UI with Godot theme
  - [ ] non actions are easily distinguished from turn-ending action 
- [ ] help screen with contextual content
- [ ] splash image as start screen background

## v1.0
- [ ] saved games
- [ ] Lyon overworld
- [ ] A Fight for Fumes campaign
- [ ] Rhymes with Remorse campaign
