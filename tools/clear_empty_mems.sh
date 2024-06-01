#! bash

find src -type f -name '*.tscn' -exec sed -i -e '/^mem = null$/d' {} \;
find src -type f -name '*.tscn-e' -delete #this is dumb
