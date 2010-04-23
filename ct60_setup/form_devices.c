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
#include "form_devices.h"

/*--- Const ---*/

static form_t form_devices[]={
	{FORM_TITLE, "Devices", FORM_X+((FORM_W-7)>>1), FORM_Y},
	{FORM_TEXT, "IDE0 : ---", FORM_X+2,FORM_Y+2},
	{FORM_TEXT, "IDE1 : ---", FORM_X+2,FORM_Y+3},
	{FORM_TEXT, "SCSI0: ---", FORM_X+2,FORM_Y+4},
	{FORM_TEXT, "SCSI1: ---", FORM_X+2,FORM_Y+5},
	{FORM_TEXT, "SCSI2: ---", FORM_X+2,FORM_Y+6},
	{FORM_TEXT, "SCSI3: ---", FORM_X+2,FORM_Y+7},
	{FORM_TEXT, "SCSI4: ---", FORM_X+2,FORM_Y+8},
	{FORM_TEXT, "SCSI5: ---", FORM_X+2,FORM_Y+9},
	{FORM_TEXT, "SCSI6: ---", FORM_X+2,FORM_Y+10},
	{FORM_TEXT, "SCSI7: ---", FORM_X+2,FORM_Y+11},
	{FORM_TEXT, "Rescan devices", FORM_X+2,FORM_Y+13},
	{FORM_END, 0,0,0}
};

/*--- Variables ---*/

const form_menu_t form_menu_devices={
	displayFormDevices,
	NULL
};

/*--- Functions ---*/

void displayFormDevices(void)
{
	vt_displayForm(form_devices);
}
