/*
	CT60 Power off

	Copyright (C) 2010	Patrice Mandin

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

#include <stdlib.h>
#include <mint/cookie.h>

#include "misc.h"

void __main(void)
{
	unsigned long dummy;
	char has_ct60, has_mint;

	has_mint = getCookie(C_MiNT, &dummy);
	if (has_mint) {
		return;
	}

	has_ct60 = getCookie(C_CT60, &dummy);
	if (!has_ct60) {
		return;
	}

	/* any write to that address causes poweroff */
	*(volatile char *) 0xFA800000L = 1;
	
	/* does not return */ 
}
