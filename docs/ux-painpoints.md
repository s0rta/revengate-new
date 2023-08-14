Major UX Pain Points
====================
Those are the most obvious inneficiencies and hard to use workflows as of v0.9.3. The leading number in the 1..10 range represents how painful the item is. Sub-items are prossible solutions with their implementation time in ideal half days (hypothetical pure-focus uninterupted half day of work).

* 2 single-tap option highlights make ghosts really obvious (mostly a problem with daggers)
  - 2 apply the alpha of the monster to the highlight marker
* 4 tapping on a far actor should do something smarter than printing a message
  - 3 pop a menu with the most obvious things to do, including "go closer"
* 3 we don't know why TravelTo is cancelled when a potiential path gets blocked
  - 1 add a message about the path
  - 4 add a highlight marker on the obstruction
* 6 when a TravelTo starts, it's unobvious to cancel
  - 4 right under the turn hour-glass, show a message about the active travel and a super obvious cancel button
* 4 impossible to toss the dynamite
* 6 it costs a turn and a trip in the inventory screen to re-equip a weapon after tossing your last dagger
  - 1 give the dagger more range, that way you actually have a turn to spare
  - ? some kind of smarter auto-reequip
* 4 no details of what the intenvory items do (stats or even description)
  - 3 tap on an item caption pops a subscreen with more details, tap-away dismissed the screen (no need to aim for a tiny "close button")
* 6 you don't know that you just tossed your last dagger
* 5 we don't know what the active weapon is without going into the inventory screen and even then it's not obvious
  - 3 show a big button with the emoji of the active weapon in one corner of the srceen, tapping the button quick attacks a nearby foe, long tap gives stats about the weapon
* ? the multi-branching traboules can easilly lead you too deep into the wrong branch
* 3 you don't know what you just looted unless you go in the inventory screen
  - 1 flash a message with the new item
* 5 it takes too many turns to loot a big stack of items
  - 4 when there are more than one things to loot, show a selection screen with checkboxes, pick everything selected in one turn action
* 2 no way to abort a run that is not going well
  - 3 add a an pane with all the rarely used actions, make "abort" one of them
* 1 no way to exit the game without killing it
  - 1 add a quit button on the home screen
* 4 panning goes too fast at high zoom level
  - 2 adjsust panning speed according to zoom level
* 3 accented letters look weird on Android
  - 1 package a base font and use that intead of the system font
* 4 there is no quest log, you need to recall what the quest NPC said
  - 6 add a screen with a summary of all the ongoing quests
* 2 you need to find which traboule to go into from a vague description
  - 2 flash a marker on demand
