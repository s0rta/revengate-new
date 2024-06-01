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
- [x] bug: victory screen is hard to scroll
- [x] bug: transient strategies are not freed after expiration
- [x] deck builder rules specific to debug mode
- [x] end of game stats
- [x] closable doors
- [x] textual tags to categorize items and monsters
- [x] use tags to identify NPC gifts
- [x] locked doors
- [x] vibe nodes
- [x] second quest

Items:
- [x] unique items are per-game unique, not only per-dungeon unique
- [x] item to increase latent healing

Combat:
- [x] silvered weapons
- [x] first stab at magic: summoning spell

UX:
- [x] something more reliable than timing to synchronize fading anims
- [x] buttons and in-dialogues choices are bigger
- [x] tap-away dismisses long-tap options

## v0.9.1
Combat:
- [x] re-balance most monsters
- [x] Monte Carlo simulator
  - [x] global flag to disable animations (wire inside Actor.is_unexposed())

## v0.9.3
UX:
- [x] single-tap does not chat with foes
- [x] highlight where you can make a single-tap action

Items:
- [x] similar items are grouped together in the inventory screen

Combat:
- [x] ranged attacks with daggers
- [x] Tracking is triggered by perception
- [x] damage numbers in the message log
- [x] healing spell (monsters only)

## V0.10
- [x] bug: cancel button for Traveling stays visible when path is blocked
- [x] bug: Tracking does not reset foe after a change of global sentiments
- [x] bug: bar patron does not perform a party trick at the start of quest 2
- [x] Godot 4.1
- [x] release on F-Droid
  - [x] add meta-data dir
  - [x] build template based on org.sajeg.fallingblocks
  - [x] factor out build number from Godot settings?
  - [x] open [inclusion request](https://gitlab.com/fdroid/rfp/-/issues/2513) with F-Droid

UX:
- [x] bug: Android font renders accented chars differently than the same letter withtout accent
- [x] bug: center on hero after victory is not working
- [x] bug: crash when restarting after death
- [x] active weapon is highlighted in a corner icon, icon is tappable for quick attack
- [x] message with the looted item(s)
- [x] pan is normalized to be fairly constant no matter what the zoom level is
- [x] multi-turn Travel is more obvious to cancel with message and bigger abort button
- [x] better description on F-Droid

New Quest – Bewitching Bookeeping:
- [x] victory screen should not mention a quest item
- [x] variable quest rewards
- [x] surface level dungeon to push the encounter further away

Monsters:
- [x] automaton
- [x] yarohu
- [x] Le Grand Salapou

Combat:
- [x] fail if meeting happened
  
## v0.11
- [x] bug: attack markers stays on after killing a monster
- [x] bug: victory screen flashes if exiting the last dungeon without killing Retznac
- [x] bug: can chat across a closed door
- [x] bug: highlights are not immediately cleared if you TravelTo right after a dialogue
- [x] bug: Travelling and Approaching are not invalidated uppon changing board
- [x] bug: gateways on Lyon Surface can end up in the river
- [x] bug: GetCloser can pick paths that cut LOS, which aborts the command since the target is not unperceived
- [x] F6 on Main scene does not show the story screen
- [x] upgrade the DialogueManager plug-in
- [x] Monte Carlo simulator for DeckBuilders
- [x] church prefab
  - [x] vibes inside the church
  - [x] crypt under the church
- [x] upgrade DialoguePane to the latest Dialogue Manager API
- [x] document the build process
- [/] bug: two finger pan is really choppy when the fingers are too close to one another

UX:
- [x] single-tap on distant actor pops a context action menu (ex.: get closer, inspect, ...)
  - [x] GetCloser command (based on Traveling)
- [x] finalize gestures to access non-default actions, see the [gestures design notes](docs/gestures.md)
- [x] health bar than turns red when low on HPs
- [x] remove the beta desclaimer
- [x] QuickAttack available on friendly actors that you recall attacking previously
- [x] flash message on why a strategy got cancelled

Items:
- [x] "magical" tag replaces the magical flag
- [x] carrot (🥕)

Vibe:
- [x] pre-fabs can inject rules in the deck generator after the geometry pass of a new board
- [x] candles (🕯)
- [x] incense 
- [x] cross (☨, ♰, ♱, ✟, 🕈, 🕆)
- [x] altar (ꟷ, 𝌁, ⚎)

Weapons:
- [x] Mjölnir

Monsters:
- [x] cherub (𝒜, 𝓒, 𝔠, 𝖈, 𝕔)
- [x] skeleton (𝖘, 𝔰)
- [x] sentry scarab
- [x] nochort
- [x] giant locust
  - [x] swarming
  - [x] poison
- [x] plasus rat

Combat:
- [x] quick attack button is easier to enable (ex: has_offended a target)
- [x] TribalTerritorial uses perception rather than dist()
- [x] healing strategy is based on health-%, not absolute number of HPs

## v0.11.1
- [x] submit to the [Game Dev World Championship](https://thegdwc.com/) (before dec 31)
- [x] submit to the Godot showreel (before dec 17)
- [x] update the F-Droid recipe with latest compatible Godot
- [x] bug: daggers can shoot through walls
- [x] bug: cross-board connectors should never be in corners
- [x] bug: TurnQueue is spinning hot on GameOver
- [x] quest summary
  - [x] save quest activation status in SaveBundle
- [x] faster move animations when there are many visible actors
- [x] play time (screen time) on victory screen 
- [x] "here" -> "Café Caché" for quest 3 summary
- [x] saved games
  - [x] restore workflow on start screen
  - [x] periodic auto-saves
  - [x] seen_locs are saved
  - [x] anims are flushed when restoring
  - [x] flying HP labels are not saved
  - [x] starting inventory is not resurected upon restore
  - [x] action highlights are refreshed properly (mem looks at id rather than references?)
  - [x] quest setup functs discover NPCs rather than using static refs
  - [x] cross-actor references are preserved in restored Actor.mem
  - [x] gifts are preserved when restoring a saved game
  - [x] health-full is persisted
  - [x] conversation checkpoints are preserved on save
- [x] bug: Exploring fails to update `me.dest` when running the live debugger on Android
      - RevBoard._on_actor_moved() called with `to` != actor.dest

Items:
- [x] items stats and long description is available from the inventory screen

## v0.11.2
- [x] regression: considerable slowdown on some devices (#15)

UX:
- [x] clickable links on the 3 start screen popup (#12)
- [x] button to go back to main menu (#10)
- [x] button to exit the game
- [x] long press popup as soon as the timeout has elapsed (#4)

## v0.11.3
Items:
- [x] fuzzy stats on low perception (#7)
- [x] long descriptions for all weapons (#7)
- [x] make it easier to scroll the inventory without poping the items description
- [x] potion of absinthe
- [x] potion of analysis paralysis

## v0.11.4
- [x] web export
  - [x] better keyboard support (ex.: ESC cancels actions)
    - [x] sub-screens are ModalScreens
    - [x] ESC cancels travel
    - [x] sub-screens on the start screen are also modal
  - [x] bug: story screen does not capture keyboard input
  - [x] save to local storage?


## v0.11.5
- [x] bug: phantruch "typical" health is -1
- [x] bug: distant actor pop-up takes precedence over inspect
- [x] tent vibe on the Salapou meeting board
- [x] bigger text on small screens
- [x] gentle degredation for missing shader params on F-Droid


## v0.11.6
- [x] settings screen
  - [x] font size
- [x] public cheats
  - [x] teleport
  - [x] x-ray inspect
  - [x] advance chapter
  - [x] used cheats show on the victory screen
  - [x] cheats have access key
  - [x] all cheats incremend the cheats counter
  - [x] context menu uses CommandButton
- [x] MacOS export preset

Items:
- [x] long descriptions for all items (#7)

UX:
- [x] quick attack button is too small with half width emojis like the broom


## v0.12.0
- [x] bug: self defence does not expire when attacker dies
- [x] bug: actors from the same spawn deck share a common memory?
- [x] bug: Exploring does not flush path after being invalid for a few turns
- [x] bug: UI button groups steal clicks
- [x] support armv7 on Google Play
- [x] pinching is centered on touch centroid
- [x] close the old play test survey
- [x] better text description on Google Play and F-Droid

Performance:
- [x] cache stats modifiers for the whole turn (with inval on mods changing events)
- [x] sort strategies by priority for early exits when starting a turn
- [x] fully typed and optimized heap queue
- [x] path finding is typed and optimized

Combat:
- [x] hero can learn spells
- [x] throwing


## v0.12.1
- [x] bug: crash on F-Droid builds when starting a game
- [x] bug: inspect and GetCloser have different perception results
- [x] close the old known issues page
- [x] F-Droid has animated water

Strategies:
- [x] Benoît roams after the meeting and after yielding
- [x] tracking monsters are more likely to crowd your exit

Combat:
- [x] zapping spell


## v0.12.3
- [x] better conversations to make a progressive reveal of the story during ch.3
- [x] better descriptions for NPCs
- [x] document the Android dependencies


## v0.12.4
- [x] bug: explosions crash the game on some Andoid devices (#24)
- [x] skip turn command
- [x] wait and heal
- [x] bug: new A* sometimes picks sub-optimal detours

UX:
- [x] dialogue responses are easier to tell apart from the speaker's chatter
- [x] show path while traveling rather than the number of turns

Performance:
- [x] async preload most shaders to speedup startup


## v0.12.5
- [x] bug: inspect screen does not take all dynamic stats modifiers into account
- [x] bug: tossing a dagger de-equips the stack
- [x] non-rectangular rooms
- [x] corridors are more twisty
- [x] bigger dialogue control buttons
- [x] better corridors that completely bisects rooms less often

## v0.12.6
- [x] deck simulator runs items and vibes
- [x] perception range is visible and animated when it changes
- [x] support Godot 4.2.2
- [x] light fixtures only glow when in line of sight
- [x] long tap to rest

Vibes:
- [x] chill
- [x] scratched floor
- [x] feathers
- [x] print shop has lots of hints: 🗜, 🖭, 🗞

Items:
- [x] coffee
- [x] eye glasses
- [x] glow mushroom


## v0.12.7
- [x] bug: mushrooms in inventory are permanently invisible after a game restore
- [x] bug: conditions are not saved
- [x] bug: only one outlaw spaws for quest 1
- [x] only keeping the active board in memory
- [x] tune vibe cost curves

## v0.12.8
- [x] bug: potion of absinthe has no breaking sound
- [x] bug: kobold has not attack sound
- [x] bug: deck simulator percentiles are innacurate
- [x] bug: tap on self corrupt the next Move command (#32)
- [x] bug: paralized is not saved (#38)
- [x] bug: new board is not saved when entering a new area
- [x] bug: ghost death sound is clipped

- [x] type a few stories
- [x] don't change Tally and Mem every time the scene is loaded in the editor
- [x] rename MeterGroup
- [ ] parlor magic is tagged as "story"
- [x] document conn_target and connection fields
- [ ] TroisGaules neighborhood uses Dungeon destination for passages rather than prefabs
- [ ] silence a few warnings
- [x] remove src/ui/explosion_vfx.gd
- [x] delete some old Python code
- [x] clear todo.txt
- [ ] self-host web exports for dev builds ( https://gist.github.com/nisovin/cf9dd74678641fb70902866c79692b17 )
- [ ] F6 on a deck builder does not init a bunch of fields in the scene file

UX:
- [x] yield message is not Critical (#31)
- [x] clear previous highlights when inspecting (#59)
- [x] more info on loot button (#54)
- [x] Talk command button (#58)
- [x] finalize long rest (#16)

Strategies:
- [x] Seeking is easier to resolve even is the target keeps moving
- [ ] plasus rats have a more aggressive version of TribalTerritorial

Maybe: 
- [ ] special icon for loot piles (#55) (🛒 or 🛍)
- [ ] phantruchs do not recover from forgivness

## v0.13
- [ ] new quest: Pacherrs are seeking some new crystals

## v1.0
- [ ] A Fight for Fumes campaign
- [ ] Rhymes with Remorse campaign

## v1.1
- [ ] packaging for Ubuntu

## Ice Box: not yet scheduled for a release
- [ ] random interlude stories
- [ ] non-walking movement and path finding (wading, swimming, phasing)
- [ ] Deck.peek(): select the next card, but do not remove it from the deck
- [ ] help screen with contextual content
- [ ] on-screen joystick
- [ ] auto-pan to hero when he gets close to the egde of the screen
- [ ] VFX: edge of water reflections 
- [ ] Allow mixing rooms and mazes in level generation
- [ ] Strategy.refresh() updates the internal index
- [ ] phantruch is destroyed if the vital assembly is broken or stolen
- [ ] startled strategy: flee when first contact is from afar, attack when from nearby
- [ ] F-Droid [Reproducible Builds](https://f-droid.org/docs/Reproducible_Builds/)
- [ ] Salapou can steal your items
- [ ] flatten the board-area node sub-tree
- [ ] try pixel fonts (ex.: https://www.dafont.com/alkhemikal.font https://www.dafont.com/retro-gaming.font )

Simulator:
- [ ] simulator auto-starts an ExtraStage if the starting board is not populated
- [ ] simulator repositions actors that are at invalid coords (out of board or inside walls)

Magic:
- [ ] spells check the Aether level of the location

Weapons:
- [ ] axe (𝇤)

Performance:
- [ ] mem.recall accept an importance param to know how deep to search
