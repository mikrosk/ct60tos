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
#include <mint/cookie.h>

#include "form_vt.h"
#include "form_bootorder.h"
#include "misc.h"
#include "ct60.h"

/*--- Define ---*/

#define FORM_BOOT	1
#define FORM_BOOT_POS	1
#define FORM_ORDER	(FORM_BOOT+1)
#define FORM_ORDER_POS	7
#define FORM_LOAD	(FORM_ORDER+1)
#define FORM_SAVE	(FORM_LOAD+1)

#define FORM_SETTING_BOOT	0
#define FORM_SETTING_ORDER	(FORM_SETTING_BOOT+1)
#define FORM_SETTING_LOAD	(FORM_SETTING_ORDER+1)
#define FORM_SETTING_SAVE	(FORM_SETTING_LOAD+1)

/*--- Const ---*/

static void reloadFromBootOrder(void);
static void saveToBootOrder(void);
static void confirmFormBootOrder(int num_setting, conf_setting_u confSetting);

static const char *dev_order[]={
	"SCSI 0-7 -> IDE 0-1",
	"IDE 0-1 -> SCSI 0-7",
	"SCSI 7-0 -> IDE 1-0",
	"IDE 1-0 -> SCSI 7-0",
	NULL
};

static form_t form_bootorder[]={
	{FORM_TITLE, "Boot order", FORM_X+((FORM_W-10)>>1), FORM_Y},
	{FORM_TEXT, "[-] New boot", FORM_X+2,FORM_Y+2},
	{FORM_TEXT, "Order: -------------------", FORM_X+2,FORM_Y+3},

	{FORM_TEXT, "Reload boot order settings", FORM_X+2,FORM_Y+5},
	{FORM_TEXT, "Save boot order settings", FORM_X+2,FORM_Y+6},
	{FORM_END, 0,0,0}
};

form_setting_t form_setting_bootorder[]={
	{FORM_X+2+FORM_BOOT_POS,FORM_Y+2, NULL, SETTING_BOOL},
	{FORM_X+2+FORM_ORDER_POS,FORM_Y+3, NULL, SETTING_LIST, 19, dev_order},

	{FORM_X+2,FORM_Y+5, NULL, SETTING_FUNC, 0, reloadFromBootOrder},
	{FORM_X+2,FORM_Y+6, NULL, SETTING_FUNC, 0, saveToBootOrder},

	{0, 0, NULL, SETTING_END}
};

/*--- Variables ---*/

static void initFormBootOrder(void);

const form_menu_t form_menu_bootorder={
	displayFormBootOrder,
	NULL,
	initFormBootOrder,
	confirmFormBootOrder
};

static char boot_devs;

/*--- Functions ---*/

static void initFormBootOrder(void)
{
	form_setting_bootorder[FORM_SETTING_BOOT].text = &form_bootorder[FORM_BOOT].text[FORM_BOOT_POS];
	form_setting_bootorder[FORM_SETTING_ORDER].text = &form_bootorder[FORM_ORDER].text[FORM_ORDER_POS];

	form_setting_bootorder[FORM_SETTING_LOAD].text = &form_bootorder[FORM_LOAD].text[0];
	form_setting_bootorder[FORM_SETTING_SAVE].text = &form_bootorder[FORM_SAVE].text[0];

	reloadFromBootOrder();
}

void displayFormBootOrder(void)
{
	form_bootorder[FORM_BOOT].text[FORM_BOOT_POS] =
		((boot_devs & 4) ? ' ' : 'X');
	strCopy(dev_order[boot_devs & 3], &form_bootorder[FORM_ORDER].text[FORM_ORDER_POS]);

	vt_displayForm(form_bootorder);
}

static void reloadFromBootOrder(void)
{
	unsigned long cookie_ct60;
	char has_ct60;

	boot_devs = 0;

	has_ct60 = getCookie(C_CT60, &cookie_ct60);

	if (!has_ct60) {
		return;
	}

	boot_devs = ct60_rw_parameter(CT60_MODE_READ, CT60_BOOT_ORDER, NULL);
}

static void saveToBootOrder(void)
{
	unsigned long cookie_ct60;
	char has_ct60;

	has_ct60 = getCookie(C_CT60, &cookie_ct60);

	if (!has_ct60) {
		return;
	}

	ct60_rw_parameter(CT60_MODE_WRITE, CT60_BOOT_ORDER, boot_devs & 7);
}

static void confirmFormBootOrder(int num_setting, conf_setting_u confSetting)
{
	int refresh_form = 0;

	switch(num_setting) {
		case FORM_SETTING_BOOT:
			boot_devs ^= 1<<2;
			refresh_form = 1;
			break;
		case FORM_SETTING_ORDER:
			boot_devs = (boot_devs & -4) | (confSetting.num_list & 3);
			refresh_form = 1;
			break;
	}

	if (refresh_form) {
		displayFormBootOrder();
	}
}
