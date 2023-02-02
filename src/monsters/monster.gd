# Copyright © 2022-2023 Yannick Gingras <ygingras@ygingras.net> and contributors

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

@tool
class_name Monster extends Actor

func act():
	state = States.ACTING
	var strat = get_strategy()
	if not strat:
		return
	var action = strat.act()
	if action != null:
		action.connect("finished", finalize_turn, CONNECT_ONE_SHOT)
	else:
		finalize_turn()
	return action
	
