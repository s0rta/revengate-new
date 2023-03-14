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

## Very common variables and game states that are used in a large number of game components.
## This script is autoloaded at `Tender`

## The tender cart of a train used to immediately follows a steam locomotive. It contained supplies and items that
## were used to keep the steam engine running properly, like coal, water, shovels, and tools.
extends Node

var hero=null
var hud=null
var viewport=null
