Major UX Pain Points
====================
Those are the most obvious inneficiencies and hard to use workflows as of v0.10.0. The leading number in the 1..10 range represents how painful the item is. Sub-items are prossible solutions with their implementation time in ideal half days (hypothetical pure-focus uninterupted half day of work).

* 6 it costs a turn and a trip in the inventory screen to re-equip a weapon after tossing your last dagger
  - 1 give the dagger more range, that way you actually have a turn to spare
  - ? some kind of smarter auto-reequip
* 4 you don't know that you just tossed your last dagger
* 5 it takes too many turns to loot a big stack of items
  - 4 when there are more than one things to loot, show a selection screen with checkboxes, pick everything selected in one turn action 
* 5 no details of what the intenvory items do (stats or even description)
  - 3 tap on an item caption pops a subscreen with more details, tap-away dismissed the screen (no need to aim for a tiny "close button")
* 4 tapping on a far actor should do something smarter than printing a message
  - 3 pop a menu with the most obvious things to do, including "go closer"
* 4 there is no quest log, you need to recall what the quest NPC said
  - 6 add a screen with a summary of all the ongoing quests
* 4 impossible to toss the dynamite
* 3 we don't know why TravelTo is cancelled when a potiential path gets blocked
  - 1 add a message about the path
  - 4 add a highlight marker on the obstruction
* 3 QuickAttack remains dissabled even after you force-attacked a friendly actor
  - 2 QuickAttack is available for anyone that you previously attacked and who is in range
* 2 you need to find which traboule to go into from a vague description
  - 2 flash a marker on demand
* 2 single-tap option highlights make ghosts really obvious (mostly a problem with daggers)
  - 2 apply the alpha of the monster to the highlight marker
* 2 no way to abort a run that is not going well
  - 3 add a an pane with all the rarely used actions, make "abort" one of them
* 1 no way to exit the game without killing it
  - 1 add a quit button on the home screen
* ? the multi-branching traboules can easilly lead you too deep into the wrong branch
* ? it's possible to scroll the whole map out of the viewport in a way that makes it confusing to bring back
