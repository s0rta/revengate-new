Developing on the Godot Revengate Codebase
=========================================

This document describes how to get started developing for latest Godot implementation of Revengate.

## Dependencies
Revengate uses Godot 4. All you need is a recent build of v4.2. The Godot engine is all self contained inside the main executable. After unpacking Godot as `godot` in your execution path, you can develop Revengate with:

`godot -e project.godot`

## Android
You need to install a few additional dependencies in order to develop for Android:

* A Java JDK (You can use openjdk-17-jdk on Ubuntu)
* the [Android SDK](https://developer.android.com/studio/#command-tools)
* an Android phone with [USB debugging enabled](https://developer.android.com/studio/command-line/adb#Enabling)
* adb (the android debugger)
* Python and the invoke package.

The Godot editor can install the game directly on your phone with the above, but you will also need a signing key if you want to produce installable packages.

You can produce the key with `keytool` (provided by the Java JDK) as described here:

* https://www.devdungeon.com/content/java-keytool-tutorial
* https://github.com/kivy/kivy/wiki/Creating-a-Release-APK

It's also possible to generate a key with OpenSSL:

* https://source.android.com/docs/core/ota/sign_builds#manually-generating-keys

Since the signing key will be different than the official Revengate signing key, you will need to completely uninstall official Revengate packages before you can install your own. This is a requirement of the Android security model: the signing key of a package cannot change for the entire lifetime of the application.

Once you have all the dependencies installed, you can run `inv make-export-presets` (possibly with `--no-signed`). After you restart Godot, you will be able to launch the game on your phone using the "remote debug" icon on the top right.

Godot automatically signs the packages that you produce from the `export` menu. You can also manually sign packages with the `apksigner` tool that comes with the Android SDK:

* `apksigner sign --ks ~/.keystore bin/revengate.apk`


## Coding style and conventions
See the [style guide](style.md).
Use the [GDScript style guide](https://docs.godotengine.org/en/latest/tutorials/scripting/gdscript/gdscript_styleguide.html) when applicable.

## Code structure
Almost everything is in `src`. Non-code assets are near their scene code, usually in the same directory. Assets that do not belong  with any scenes or that are heavily used across scenes are in `assets`.

## Artwork
Artwork must be licensed under one of CC-BY, CC-BY-SA (4.0+), CC0, or GPLv3. 

CC-NC and CC-NC-SA are not GPL compatible and are therefore not usable in this project. More details here:
https://creativecommons.org/share-your-work/licensing-considerations/compatible-licenses
https://fedoraproject.org/wiki/Licensing:Main?rd=Licensing#Content_Licenses
https://help.ubuntu.com/community/Repositories/Ubuntu

