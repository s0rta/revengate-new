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
- [x] all monsters have self-defense

UI:
- [x] bug: "follow stairs" button hidden after changing board
- [x] bug: beastiary description font color is sometimes black
- [x] inspect command appends messages for tile types and items
- [x] narrations
- [x] finely tuned animation overlaps
  - [x] `Actor.act()` does not wait for the end of animations before calling `finalize_turn()`
- [x] visual feedback for when inputs are accepted
- [x] messages pane

## v0.6
- [x] bug: death does not make items under the victim reappear
- [x] style UI with Godot theme
  - [x] non actions are easily distinguished from turn-ending action 
- [x] splash image as the start screen background
- [x] water ripples VFX

Combat:
- [x] Dynamite

Builder:
- [x] items and monsters selected with parametric decks
- [x] mazes can fill arbitrary areas of a board

UI: 
- [x] ability to cancel a multi-turn command
- [x] ability to completely skip dialogues
- [x] long press for context menu (in GDScript)
- [x] use the Godot mobile renderer

## v0.7
- [x] new level design for Lyon surface
- [x] new starting quest: Cards Collection about retreiving stolen loom punch cards
- [x] bug: "follow stairs" is the wrong button label for horizontal gateways
- [x] bug: no message when getting potions from barman
- [x] connector tiles should always be stairs when changing elevation

VFX:
- [x] water highlights 

Combat:
- [x] TribalTerritorial strategy
- [x] Quest NPC has self defense
- [x] death drops
- [x] umbrella

Builder:
- [x] more than one way up or down on some levels

## v0.8
- [x] all buttons fire on Up rather than Pressed for Windows 11 compatibility
- [x] stairs are further apart
- [x] start screen makes it clear when running a debug build

Progen:
- [x] prefabs invocation system
- [x] river prefab

Items:
- [x] potion of booze: heals, but impairs perception and agility
- [x] explosions start a particles system

Combat:
- [x] perception affect who you can see

UX:
- [x] pinch to zoom
- [x] Lyon overworld map

## v0.9
- [ ] bug: victory screen is hard to scroll
- [ ] bug: transient strategies are not freed after expiration
- [x] end of game stats
- [x] closable doors
- [x] textual tags to categorize items and monsters
- [x] use tags to identify NPC gifts
- [x] locked doors
- [x] vibe nodes
- [ ] second quest

Items:
- [ ] unique items are per-game unique, not only per-dungeon unique
- [ ] item to increase latent healing

Combat:
- [x] silvered weapons
- [x] first stab at magic: summoning spell

UX:
- [x] something more reliable than timing to synchronize fading anims
- [ ] buttons and in-dialogues choices are bigger
- [ ] tap-away dismisses long-tap options

## V0.10
Items:
- [ ] potion of absinthe
- [ ] "magical" tag replaces the magical flag

Combat:
- [ ] TribalTerritorial uses perception rather than dist()
- [ ] Tracking is triggered by perception


## v??? – when Godot 4 enables the Android gestures recognition
- [ ] gesture to access non-default actions, like following stairs see [docs/gestures.md]

  
## v1.0
- [ ] release on F-Droid
- [ ] saved games
- [ ] A Fight for Fumes campaign
- [ ] Rhymes with Remorse campaign


## Ice Box: not yet scheduled for a release
- [ ] Monte Carlo simulator
  - [ ] global flag to disable animations (wire inside Actor.is_unexposed())
- [ ] non-walking movement and path finding (wading, swimming, phasing)
- [ ] Deck.peek(): select the next card, but do not remove it from the deck
- [ ] help screen with contextual content
- [ ] on-screen joystick
- [ ] pre-fabs can inject rules in the deck generator after the geometry pass of a new board
- [ ] auto-pan to hero when he gets close to the egde of the screen
- [ ] VFX: edge of water reflections 
- [ ] items long descriptions
- [ ] Allow mixing rooms and mazes in level generation
- [ ] Strategy.refresh() updates the internal index
- [ ] phantruch is destroyed if the vital assembly is broken or stolen
- [ ] startled strategy: flee when first contact is from afar, attack when from nearby
