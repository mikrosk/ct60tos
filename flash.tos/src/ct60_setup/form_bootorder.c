/*
	CT60 Setup
	Storage devices

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
#include <mint/falcon.h>

#include "form_vt.h"
#include "form_bootorder.h"

/*--- Const ---*/

static form_t form_bootorder[]={
	{FORM_TITLE, "Boot order", FORM_X+((FORM_W-10)>>1), FORM_Y},
	{FORM_TEXT, "Floppy disk", FORM_X+2,FORM_Y+2},
	{FORM_TEXT, "IDE hard disk", FORM_X+2,FORM_Y+3},
	{FORM_TEXT, "SCSI hard disk", FORM_X+2,FORM_Y+4},
	{FORM_END, 0,0,0}
};

/*--- Variables ---*/

const form_menu_t form_menu_bootorder={
	displayFormBootOrder,
	NULL
};

/*--- Functions ---*/

void displayFormBootOrder(void)
{
	vt_displayForm(form_bootorder);
}
