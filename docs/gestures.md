Gesture Handling on Mobile
==========================

## Blockers
Godot 4 has limited support for multi-touch gestures until the [refactored core gesture handler](https://github.com/godotengine/godot/pull/65434) is enabled in production builds. Implementing the gesture handling is therefore postponed until the feature is enabled or until we decide to make our own Godot builds if this drags significantly passed Revengate v0.6.

## Single Tap
Single Tap does the most obvious default action: attack an enemy, talk to a friend, or start traveling toward an unoccupied cell. Single Tap doesn't do anything non-obvious, such as swapping position with a neutral (non-friendly) NPC.

## Double Tap
Double tap should do the second most obvious thing for a position: going down some stairs, move then pick a pile of loot.

## Long Tap
Long tap opens a context menu with a comprehensive list of actions. The default actions for tap and double tap should be highlighted (with 👆 and 👆x2). Currently unavailable actions may be included. If included, they should grayed out and available actions should be moved to the top of the menu to reduce clutter and the need for scrolling.
