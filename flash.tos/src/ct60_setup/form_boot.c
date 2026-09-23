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

#include <stdint.h>
#include <stdlib.h>

#include <mint/osbind.h>
#include <mint/falcon.h>
#include <mint/cookie.h>

#include "setup.h"
#include "form_vt.h"
#include "form_boot.h"
#include "misc.h"
#include "ct60.h"

/*--- Define ---*/

#define FORM_BOOT	1
#define FORM_BOOT_POS	1
#define FORM_ORDER	(FORM_BOOT+1)
#define FORM_ORDER_POS	7
#define FORM_LOG	(FORM_ORDER+1)
#define FORM_LOG_POS	1
#define FORM_TOS	(FORM_LOG+1)
#define FORM_TOS_POS	1
#define FORM_PCIIDE	(FORM_TOS+1)
#define FORM_PCIIDE_POS	1
#define FORM_LOAD	(FORM_PCIIDE+1)
#define FORM_SAVE	(FORM_LOAD+1)

#define FORM_SETTING_BOOT	0
#define FORM_SETTING_ORDER	(FORM_SETTING_BOOT+1)
#define FORM_SETTING_LOG	(FORM_SETTING_ORDER+1)
#define FORM_SETTING_TOS	(FORM_SETTING_LOG+1)
#define FORM_SETTING_PCIIDE	(FORM_SETTING_TOS+1)

#define FORM_SETTING_LOAD	(FORM_SETTING_PCIIDE+1)
#define FORM_SETTING_SAVE	(FORM_SETTING_LOAD+1)

/*--- Const ---*/

static void reloadFromBoot(void);
static void saveToBoot(void);
static void confirmFormBoot(int num_setting, conf_setting_u confSetting);

static const char *dev_order[]={
	"SCSI 0-7 -> IDE 0-1",
	"IDE 0-1 -> SCSI 0-7",
	"SCSI 7-0 -> IDE 1-0",
	"IDE 1-0 -> SCSI 7-0",
	NULL
};

static form_t form_boot[]={
	{FORM_TITLE, "CT60 BOOT", FORM_X+((FORM_W-9)>>1), FORM_Y},
	{FORM_TEXT, "[-] New boot", FORM_X+2,FORM_Y+2},
	{FORM_TEXT, "Order: -------------------", FORM_X+2,FORM_Y+3},

	{FORM_TEXT, "[-] Log boot to boot.log", FORM_X+2,FORM_Y+5},
	{FORM_TEXT, "[-] Copy TOS to SDRAM on boot", FORM_X+2,FORM_Y+7},

	{FORM_TEXT, "[-] Boot from CTPCI IDE Controller", FORM_X+2, FORM_Y+9},

	{FORM_TEXT, "Reload CT60 boot settings", FORM_X+2,FORM_Y+11},
	{FORM_TEXT, "Save CT60 boot settings", FORM_X+2,FORM_Y+12},
	{FORM_END, 0,0,0}
};

form_setting_t form_setting_boot[]={
	{FORM_X+2+FORM_BOOT_POS,FORM_Y+2, NULL, SETTING_BOOL},
	{FORM_X+2+FORM_ORDER_POS,FORM_Y+3, NULL, SETTING_LIST, 19, dev_order},

	{FORM_X+2+FORM_LOG_POS,FORM_Y+5, NULL, SETTING_BOOL},
	{FORM_X+2+FORM_TOS_POS,FORM_Y+7, NULL, SETTING_BOOL},
	{FORM_X+2+FORM_PCIIDE_POS,FORM_Y+9, NULL, SETTING_BOOL},
	{FORM_X+2,FORM_Y+11, NULL, SETTING_FUNC, 0, reloadFromBoot},
	{FORM_X+2,FORM_Y+12, NULL, SETTING_FUNC, 0, saveToBoot},

	{0, 0, NULL, SETTING_END}
};

/*--- Variables ---*/

static void initFormBoot(void);

const form_menu_t form_menu_boot={
	displayFormBoot,
	NULL,
	initFormBoot,
	confirmFormBoot
};

static char boot_devs;
static char boot_devs_load;
static uint32_t boot_log;
static uint32_t boot_log_load;
static uint32_t boot_tos;
static uint32_t boot_tos_load;
static uint32_t boot_ctpci;
static uint32_t boot_ctpci_load;

/*--- Functions ---*/

static void initFormBoot(void)
{
	form_setting_boot[FORM_SETTING_BOOT].text = &form_boot[FORM_BOOT].text[FORM_BOOT_POS];
	form_setting_boot[FORM_SETTING_ORDER].text = &form_boot[FORM_ORDER].text[FORM_ORDER_POS];
	form_setting_boot[FORM_SETTING_LOG].text = &form_boot[FORM_LOG].text[FORM_LOG_POS];
	form_setting_boot[FORM_SETTING_TOS].text = &form_boot[FORM_TOS].text[FORM_TOS_POS];

	form_setting_boot[FORM_SETTING_PCIIDE].text = &form_boot[FORM_PCIIDE].text[FORM_PCIIDE_POS];

	form_setting_boot[FORM_SETTING_LOAD].text = &form_boot[FORM_LOAD].text[0];
	form_setting_boot[FORM_SETTING_SAVE].text = &form_boot[FORM_SAVE].text[0];

	reloadFromBoot();
}

void displayFormBoot(void)
{
	form_boot[FORM_BOOT].text[FORM_BOOT_POS] = ((boot_devs & 4) ? ' ' : 'X');
	strCopy(dev_order[boot_devs & 3], &form_boot[FORM_ORDER].text[FORM_ORDER_POS]);

	form_boot[FORM_LOG].text[FORM_LOG_POS] = ((boot_log & 1) ? ' ' : 'X');
	form_boot[FORM_TOS].text[FORM_TOS_POS] = ((boot_tos & 1) ? 'X' : ' ');
	form_boot[FORM_PCIIDE].text[FORM_PCIIDE_POS] = ((boot_ctpci & 1) ? 'X' : ' ');

	vt_displayForm(form_boot);
}

static void reloadFromBoot(void)
{
	boot_devs = 0;
	boot_log = 1;
	boot_tos = 1;
	boot_ctpci = 0;

	if (!has_ct60) {
		return;
	}

	boot_devs_load = boot_devs = ct60_rw_parameter(CT60_MODE_READ, CT60_BOOT_ORDER, NULL);
	boot_log_load  = boot_log  = ct60_rw_parameter(CT60_MODE_READ, CT60_BOOT_LOG, NULL);
	boot_tos_load  = boot_tos  = ct60_rw_parameter(CT60_MODE_READ, CT60_PARAM_TOSRAM, NULL);
	boot_ctpci_load= boot_ctpci= ct60_rw_parameter(CT60_MODE_READ, CT60_PARAM_CTPCI, NULL)&0x7fffffff;

	displayFormBoot();
}

static void saveToBoot(void)
{
	if (!has_ct60) {
		return;
	}

	if (boot_devs!=boot_devs_load) ct60_rw_parameter(CT60_MODE_WRITE, CT60_BOOT_ORDER, boot_devs & 7);
	if (boot_log!=boot_log_load) ct60_rw_parameter(CT60_MODE_WRITE, CT60_BOOT_LOG, boot_log);
	if (boot_tos!=boot_tos_load) ct60_rw_parameter(CT60_MODE_WRITE, CT60_PARAM_TOSRAM, boot_tos);
	if (boot_ctpci!=boot_ctpci_load) ct60_rw_parameter(CT60_MODE_WRITE, CT60_PARAM_CTPCI, boot_ctpci);
}

static void confirmFormBoot(int num_setting, conf_setting_u confSetting)
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
		case FORM_SETTING_LOG:
		        boot_log ^= 1;
			refresh_form = 1;
			break;
		case FORM_SETTING_TOS:
		        boot_tos ^= 1;
			refresh_form = 1;
			break;
		case FORM_SETTING_PCIIDE:
			boot_ctpci ^= 1;
			refresh_form = 1;
			break;
	}

	if (refresh_form) {
		displayFormBoot();
	}
}
