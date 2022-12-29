Developing on the Godot Revengate Codebase
=========================================

This document describes how to get started developing for latest Godot implementation of Revengate.

## Dependencies
Revengate uses Godot 4. All you need is a recent build of v4.0. The Godot engine is all self contained inside the main executable. After unpacking Godot as `godot` in your execution path, you can develop Revengate with:

`godot -e project.godot`

## Coding style and conventions
See the [style guide](style.md).

## Code structure
Almost everything is in `src`. Non-code assets are near their scene code, usually in the same directory. Assets that do not belong  with any scenes or that are heavily used across scenes are in `assets`.

## Artwork
Artwork must be licensed under one of CC-BY, CC-BY-SA (4.0+), CC0, or GPLv3. 

CC-NC and CC-NC-SA are not GPL compatible and are therefore not usable in this project. More details here:
https://creativecommons.org/share-your-work/licensing-considerations/compatible-licenses
https://fedoraproject.org/wiki/Licensing:Main?rd=Licensing#Content_Licenses
https://help.ubuntu.com/community/Repositories/Ubuntu

