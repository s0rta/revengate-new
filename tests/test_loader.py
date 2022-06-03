# Copyright © 2022 Yannick Gingras <ygingras@ygingras.net> and contributors

# This file is part of Revengate.

# Revengate is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Revengate is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with Revengate.  If not, see <https://www.gnu.org/licenses/>.


from revengate.tags import Tag, t
from revengate.loader import TopLevelLoader, TemplatizedObjectsLoader


HEADER = """
[RevengateFile]
format = 0
content = "templatized-objects"
"""






class Foo:
    def __init__(self, bar, baz):
        self.bar = bar
        self.baz = baz

class NamedObj:
    def __init__(self, name):
        self.name = name

TemplatizedObjectsLoader.loadable_classes += [Foo, NamedObj]


SAMPLE_1 = f"""{HEADER}
[instances]
[instances.something]
_class = "Foo"
bar = "this is something"
baz = 42

[templates]
"""


def test_get_instance():
    loader = TopLevelLoader()
    loader.loads(SAMPLE_1)
    thing = loader.get_instance("something")
    assert thing.bar == "this is something"


SAMPLE_2 = f"""{HEADER}
[instances]

[templates]
[templates.composite_base]
_class = "Foo"
bar = "composite"
baz = ["one"]

[templates.composite]
_parent = "composite_base"
"+baz" = ["two"]
"""


def test_list_append():
    loader = TopLevelLoader()
    loader.loads(SAMPLE_2)
    thing = loader.invoke("composite")
    assert len(thing.baz) == 2
    assert "two" in thing.baz


SAMPLE_3 = f"""{HEADER}
[instances]
[instances.tag1]
_class = "Tag"

[templates]
[templates.inner]
_class = "NamedObj"

[templates.outer1]
_class = "Foo"
bar = "*inner"
baz = "*inner"

[templates.outer2]
_class = "Foo"
bar = ["*inner", "*inner"]
baz = ["#tag1", "#tag1"]
"""


def test_sub_template():
    loader = TopLevelLoader()
    loader.loads(SAMPLE_3)
    thing = loader.invoke("outer1")
    assert thing.bar.name == "inner"
    # sub-templates must create new instance each time they are invoked
    assert thing.bar is not thing.baz

    thing = loader.invoke("outer2")
    assert len(thing.bar) == 2 
    assert thing.bar[0] is not thing.bar[1]
    
    # tags are always loaded from the registry, which preserves identity
    assert thing.baz[0] is thing.baz[1]
    assert thing.baz[0] is t("tag1")


SAMPLE_4 = f"""{HEADER}
[instances]
[instances.inner]
_class = "NamedObj"

[templates]

[templates.outer]
_class = "Foo"
bar = "@inner"
baz = "@inner"
"""
    

def test_instance_ref():
    loader = TopLevelLoader()
    loader.loads(SAMPLE_4)
    thing = loader.invoke("outer")
    assert thing.bar.name == "inner"
    # instance refs return the object from the registry, identity is preserved
    assert thing.bar is thing.baz


SAMPLE_5 = f"""{HEADER}
[instances]
[instances.tag1]
_class = "Tag"

[instances.inner]
_class = "NamedObj"

[templates]

[templates.outer]
_class = "Foo"
bar = {{"#tag1" = "@inner"}}
baz = [["b", "@inner"], ["#tag1", "#tag1"]]
"""


def test_instance_ref_in_deeply_nested():
    """ Test that instance refs are expanded even when deeply nested. """
    loader = TopLevelLoader()
    loader.loads(SAMPLE_5)
    thing = loader.invoke("outer")
    assert isinstance(thing.bar, dict)
    assert thing.bar["tag1"].name == "inner"

    key, val = thing.baz[0]
    assert val.name == "inner"
