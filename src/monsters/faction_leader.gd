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

extends Actor

func spawn():
	if not was_offended.is_connected(hate_faction):
		was_offended.connect(hate_faction)
	super()

func hate_faction(offender):
	if offender != null and Tender.sentiments:
		Tender.sentiments.set_sentiment(faction, offender.faction, -1.0)
		
func forgive(other:Actor):
	super(other)
	Tender.sentiments.set_sentiment(faction, other.faction, 0.0)
