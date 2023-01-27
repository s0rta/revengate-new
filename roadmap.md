Revengate Godot Roadmap
=======================

Major parts required to make the Godot implementation of Revengate a playable game.

## Minimum Viable Game (v0.2)
- [x] release to Google Play

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

## v0.3
- [x] victory conditions
- [ ] release to Google Play
- [x] cheat codes

Combat:
- [x] no poison on default monsters nor hero
- [x] items for progression
- [x] damage over time
- [x] healing

Builder:
- [x] quest item is deeper on a random level and unique

UI:
- [x] all contributors on credits screen
- [x] flying HPs are bigger
- [x] inventory screen
- [x] privacy screen
- [x] bug: cliking on dark area crashes the game
- [x] bug: the cheats pannel captures click even when hidden

## v0.4

Combat:
- [ ] new evasion stat to increase all to-hit rolls
- [x] no poison on the first few monsters

Builder:
- [ ] mazes can fill arbitrary areas of a board

UI:
- [ ] visual feedback for when inputs are accepted
- [ ] gesture to access non-default actions, like following stairs see [docs/gestures.md]
- [ ] pinch to zoom

## v0.5
- [x] merge git repo with Revengate v0.1
- [ ] release on F-Droid

UI: 
- [ ] narrations
- [ ] dialogues
- [ ] bestiary
- [ ] finely tuned animation overlaps
- [ ] messages pane
- [x] messages history screen

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
