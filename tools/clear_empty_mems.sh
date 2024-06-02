#!/bin/sh
# cleanup empty memories from scene files

find src -type f -name '*.tscn' -exec sed -i -e '/^mem = null$/d' {} \;
find src -type f -name '*.tscn-e' -delete  # remove the sed backup files on MacOS
