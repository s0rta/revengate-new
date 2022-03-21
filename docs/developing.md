Developing Revengate
====================

## Dependencies
Most of the pure Python dependencies are specified in Pipfile. This command should install them all for you:
`pipenv install --dev`

There are many non-Python dependencies, almost all for the Android backend. On Ubuntu 21.10, this works to get you up to speed:
`sudo apt install -y build-essentials java-common default-jre default-jdk and libjffi-java google-android-build-tools-24-installer android-sdk-build-tools android-sdk-platform-tools android-sdk-platform-23 android-sdk libltdl7-dev`

It's probably possible to simplify this list, but the errors you get come very late and are rather cryptic. 

More details are available in the Kivy official documentation:
https://buildozer.readthedocs.io/en/latest/installation.html#targeting-android


## Coding style and conventions
* max line length is 88
* pos, which stands for position is always an (x, y) tuple in carterian coordinates (origin at bottom left corner).
* tile: what the environment is made of at a given pos (floor, wall, door, ...)
* funct, not func: a Python callable
* action and ftag: a string referencing a registered Python function; must be resolved before it can be called
* params, not parms
* hero: the player character, never referrer to as PC
* when in doubt, name things after steam engine parts or concepts at the core of the industrial revolution


## Artwork
Artwork must be licenced under one of CC-BY, CC-BY-SA (4.0+), CC0, or GPLv3. 

CC-NC and CC-NC-SA are not GPL compatible and are therefore not usable in this project. More details here:
https://creativecommons.org/share-your-work/licensing-considerations/compatible-licenses
https://fedoraproject.org/wiki/Licensing:Main?rd=Licensing#Content_Licenses
https://help.ubuntu.com/community/Repositories/Ubuntu

