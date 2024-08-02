# Copyright © 2024 Yannick Gingras <ygingras@ygingras.net> and contributors

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

## Various utility functions to help with the UI and UX.
class_name UIUtils extends Object

const LONG_TAP_SECS := 0.5

static func resize_text_controls(size=null):
	if size == null:
		size = Tabulator.load().text_size
	var alt_theme = null
	if size == Consts.TextSizes.BIG:
		alt_theme = load("res://src/ui/theme_big.tres")
	elif size == Consts.TextSizes.HUGE:
		alt_theme = load("res://src/ui/theme_really_big.tres")
	else:
		# If the theme has never been touched, we don't have to force load from disk.
		# We could detect that by connecting to Theme.changed.
		alt_theme = ResourceLoader.load("res://src/ui/theme.tres", "", ResourceLoader.CACHE_MODE_IGNORE)

	var theme = ThemeDB.get_project_theme()
	theme.merge_with(alt_theme)

static func format_modifiers(mods:Dictionary, strip_blanks=true):
	## Return a {key:val_str} mapping suitable for presenting to the player
	var modstrs := {}
	for key in mods:
		if strip_blanks and not mods[key]:
			pass
		if mods[key] is int:
			modstrs[key] = "%+d" % mods[key]
		elif key.ends_with("_prob"):
			modstrs[key] = "%+0.1f%%" % (100.0 * mods[key])
		elif mods[key] is float:
			modstrs[key] = "%+0.1f" % mods[key]
		else:
			modstrs[key] = "%s" % mods[key]
	return modstrs
