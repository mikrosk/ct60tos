/*
	CT60 Setup
	Video mode save and restore

	Copyright (C) 2009	Patrice Mandin

	This program is free software; you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation; either version 2 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program; if not, write to the Free Software
	Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#include <mint/falcon.h>

static void *old_logbase, *old_physbase;
static unsigned short old_vmode;

void video_save(void)
{
	unsigned short vmode;

	old_logbase = Logbase();
	old_physbase = Physbase();
	old_vmode = VsetMode(-1);

	vmode = old_vmode & (0xfe00|VGA|PAL);

	switch(VgetMonitor()) {
		case 0:
			/* Keep 640x400 */
			break;
		case 2:
			/* Set 640x480x16 (vga) */
			vmode |= BPS4|COL80;
			VsetScreen(0,0,3,vmode);
			break;
		default:
			/* Set 640x240x16 (tv) */
			vmode |= BPS4|COL80;
			VsetScreen(0,0,3,vmode);
			break;
	}
	
	Vsync();
}

void video_restore(void)
{
	VsetScreen(old_logbase, old_physbase, 3, old_vmode);
	Vsync();
}
