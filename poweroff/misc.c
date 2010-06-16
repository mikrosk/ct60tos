/*
	CT60 Setup
	Misc functions

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

#include <stdlib.h>

#include <mint/osbind.h>
#include <mint/sysvars.h>

int getCookie(unsigned long name, unsigned long *value)
{
	unsigned long *pCookie;
	void *old_stack;
	
	old_stack = (void *) Super(0);
	pCookie = *_p_cookies;
	Super(old_stack);

	if (pCookie == NULL) {
		return 0;
	}

	while (pCookie[0]) {
		if (pCookie[0] == name) {
			*value = pCookie[1];
			return 1;
		}
		pCookie += 2;
	}

	return 0;
}
