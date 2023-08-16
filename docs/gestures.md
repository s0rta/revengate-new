Gesture Handling on Mobile
==========================

## Single Tap
Single Tap does the most obvious default action: attack an enemy, talk to a friend, or start traveling toward an unoccupied cell. Single Tap doesn't do anything non-obvious, such as swapping position with a neutral (non-friendly) NPC.

## Double Tap
Double tap should do the second most obvious thing for a position: going down some stairs, move then pick a pile of loot. Godot emits the single tap before the double tap event, so adding support for double tap gestures will require gating all single taps behind a timer.

## Long Tap
Long tap opens a context menu with a comprehensive list of actions. The default actions for tap and double tap should be highlighted (with 👆 and 👆x2). Currently unavailable actions may be included. If included, they should be grayed out and available actions should be moved to the top of the menu to reduce clutter and the need for scrolling.
