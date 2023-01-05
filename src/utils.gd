# Copyright © 2023 Yannick Gingras <ygingras@ygingras.net> and contributors

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

extends Object

## Various utility functions that don't fit anywhere else.
class_name Utils

static func ddump_event(event, node, meth_name):
	## Print a trace that event was received by node.meth_name(). 
	## Note all events are printed, only those with high debug-value.
	if not event is InputEventMouseMotion:
		print("%s.%s(%s)" % [node.name, meth_name, event])
