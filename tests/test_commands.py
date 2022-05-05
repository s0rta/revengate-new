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

from pytest import raises

from revengate.commands import CommandMap, no_auto_reg


class SampleMap(CommandMap):
    def foo(self):
        pass
    
    @no_auto_reg
    def bar(self):
        pass
    
    
def test_auto_reg():
    commands = SampleMap("test commands")
    assert callable(commands["foo"])

    with raises(ValueError):
        funct = commands["bar"]


def test_nesting():
    """ Make sure that commands registered with a sub-map are visible from the parent 
    map."""
    def baz():
        pass
    
    commands = SampleMap("test commands")
    other_cmds = CommandMap("sub-map")
    other_cmds.register(baz)
    commands.register_sub_map(other_cmds)
    assert callable(commands["baz"])


def test_prefix(capsys):
    commands = SampleMap("prefixed commands", prefix="qux-")
    print(commands.summary())
    captured = capsys.readouterr()
    assert "qux-foo" in captured.out
    assert callable(commands["qux-foo"])
    with raises(ValueError):
        funct = commands["foo"]
        
