#!/bin/bash

# Build Godot and Revengate from clean git checkouts, more or less using the same steps 
# used by the F-Droid build pipeline:
# https://gitlab.com/fdroid/fdroiddata/-/blob/master/metadata/org.revengate.revengate.yml?ref_type=heads

# Build dependencies are listed in the official Godot docs:
# https://docs.godotengine.org/en/stable/contributing/development/compiling/compiling_for_linuxbsd.html
# https://docs.godotengine.org/en/stable/contributing/development/compiling/compiling_for_android.html

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export ANDROID_SDK_ROOT=~/proj/android-dev/
export ANDROID_NDK_ROOT=~/proj/android-dev/ndk/23.2.8568313

export GODOT_DIR=/tmp/godot-clean
export GODOT=$GODOT_DIR/bin/godot.linuxbsd.editor.x86_64

rm -rf $GODOT_DIR
git clone ~/proj/godot $GODOT_DIR
cd $GODOT_DIR

git checkout 4.2.2-stable

scons platform=linuxbsd target=editor
scons platform=android target=template_release arch=arm64
cd platform/android/java
./gradlew generateGodotTemplates

rm -rf /tmp/rev-clean
git clone ~/proj/revengate /tmp/rev-clean
cd /tmp/rev-clean

# git checkout v0.11.6

mkdir bin
invoke make-fdroid-presets $GODOT_DIR
$GODOT --headless --export-release 'Android APK' bin/revengate.apk
$GODOT --headless --export-release 'Android APK' bin/revengate.apk
