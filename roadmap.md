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
- [x] merge git repo with Revengate v0.1
- [x] victory conditions
- [x] release to Google Play
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
Strategies: 
- [x] bug: TravelTo stopped working with Godot 4b16

Combat:
- [x] weapons are items, can be wielded
- [x] new evasion stat to increase all to-hit rolls
- [x] no poison on the first few monsters
- [x] effects have a probability, should not trigger at every hit

UI:
- [x] bug: items stay hidden after the actor standing over a stack then dies
- [x] dialogues
- [x] bestiary
- [x] messages history screen

## v0.5
Combat:
- [x] deprecate the Monster class: too vague to be useful
- [x] multi-attacks (ex.: claw + claw + bite)
- [ ] all monsters have self-defense

UI:
- [x] bug: "follow stairs" button hidden after changing board
- [x] bug: beastiary description font color is sometimes black
- [x] inspect command appends messages for tile types and items
- [x] narrations
- [x] finely tuned animation overlaps
  - [x] `Actor.act()` does not wait for the end of animations before calling `finalize_turn()`
- [ ] visual feedback for when inputs are accepted
- [x] messages pane

## v0.6
- [ ] style UI with Godot theme
  - [ ] non actions are easily distinguished from turn-ending action 
- [ ] help screen with contextual content
- [ ] splash image as the start screen background

Builder:
- [ ] mazes can fill arbitrary areas of a board

UI: 
- [ ] ability to cancel a multi-turn command
- [ ] ability to completely skip dialogues

## v??? – when Godot 4 enables the Android gestures recognition
- [ ] gesture to access non-default actions, like following stairs see [docs/gestures.md]
- [ ] pinch to zoom
- [ ] double tap for context menu
  - might not work since a single tap fires and fully propagates before we see the double tap

## v1.0
- [ ] release on F-Droid
- [ ] saved games
- [ ] Lyon overworld
- [ ] A Fight for Fumes campaign
- [ ] Rhymes with Remorse campaign
