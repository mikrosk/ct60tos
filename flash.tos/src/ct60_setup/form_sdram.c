/*
	CT60 Setup
	SDRAM settings

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
#include "form_sdram.h"
#include "misc.h"
#include "ct60.h"
#include "ct60_ctcm.h"
#include "ct60_sdram.h"

/*--- Defines ---*/

#define FORM_MEMTYPE 1
#define FORM_MEMTYPE_POS 13
#define FORM_ROWS (FORM_MEMTYPE+1)
#define FORM_ROWS_POS 14
#define FORM_COLUMNS (FORM_ROWS+1)
#define FORM_COLUMNS_POS 17
#define FORM_BANKS (FORM_COLUMNS+1)
#define FORM_BANKS_POS 12
#define FORM_WIDTH (FORM_BANKS+1)
#define FORM_WIDTH_POS 19
#define FORM_VOLT (FORM_WIDTH+1)
#define FORM_VOLT_POS 25
#define FORM_CYCLE (FORM_VOLT+1)
#define FORM_CYCLE_POS_INT 12
#define FORM_CYCLE_POS_FRAC 15
#define FORM_ACCESS (FORM_CYCLE+1)
#define FORM_ACCESS_POS_INT 19
#define FORM_ACCESS_POS_FRAC 22
#define FORM_CONFIG (FORM_ACCESS+1)
#define FORM_CONFIG_POS 15
#define FORM_REFRESH (FORM_CONFIG+1)
#define FORM_REFRESH_POS 14
#define FORM_NUMBANKS (FORM_REFRESH+1)
#define FORM_NUMBANKS_POS 17
#define FORM_PRECHARGE (FORM_NUMBANKS+1)
#define FORM_PRECHARGE_POS 28
#define FORM_ACTIVE (FORM_PRECHARGE+1)
#define FORM_ACTIVE_POS 36
#define FORM_RASCAS (FORM_ACTIVE+1)
#define FORM_RASCAS_POS 26
#define FORM_DENSITY (FORM_RASCAS+1)
#define FORM_DENSITY_POS 21
#define FORM_MANID (FORM_DENSITY+1)
#define FORM_MANID_POS 24
#define FORM_MANDATE (FORM_MANID+1)
#define FORM_MANDATE_POS 27
#define FORM_MANDATE_POS_YEAR 30
#define FORM_ATTR (FORM_MANDATE+1)
#define FORM_ATTR_POS 19

#define CHAR_MU "\xe6"

/*--- Const ---*/

static char *sdram_type="SDRAM";

static char *sdram_config[3]={
	"No parity",
	"Parity   ",
	"ECC      "
};

static char *sdram_refresh[6]={
	"15.625 " CHAR_MU "s",
	"3.9 " CHAR_MU "s   ",
	"7.8 " CHAR_MU "s   ",
	"31.3 " CHAR_MU "s  ",
	"62.5 " CHAR_MU "s  ",
	"125 " CHAR_MU "s   "
};

static char *sdram_manufacturers[13]={
	"\x1c" "Mitsubishi",
	"\x25" "Kingmax",
	"\x2c" "Micron",
	"\x4a" "Compaq",
	"\x54" "HP",
	"\x98" "Kingston",
	"\x9e" "Corsair",
	"\xa4" "IBM",
	"\xc1" "Infineon",
	"\xce" "Samsung",
	"\xda" "Dane-Elec",
	"\xad" "Hyundai",
	"\xe0" "Hyundai"
};

static form_t form_sdram[]={
	{FORM_TITLE, "SDRAM", FORM_X+((FORM_W-5)>>1), FORM_Y},
	{FORM_TEXT, "Memory type: -----", FORM_X+2,FORM_Y+2},
	{FORM_TEXT, "Address rows: ---", FORM_X+2,FORM_Y+3},
	{FORM_TEXT, "Address columns: ---", FORM_X+2,FORM_Y+4},
	{FORM_TEXT, "DIMM banks: ---", FORM_X+2,FORM_Y+5},
	{FORM_TEXT, "Module data width: ----- bits", FORM_X+2,FORM_Y+6},
	{FORM_TEXT, "Voltage interface level: --- LVTTL", FORM_X+2,FORM_Y+7},
	{FORM_TEXT, "Cycle time: --.-- ns", FORM_X+2,FORM_Y+8},
	{FORM_TEXT, "Access from clock: --.-- ns", FORM_X+2,FORM_Y+9},
	{FORM_TEXT, "Configuration: ---------", FORM_X+2,FORM_Y+10},
	{FORM_TEXT, "Refresh rate: ---------", FORM_X+2,FORM_Y+11},
	{FORM_TEXT, "Number of banks: ---", FORM_X+2,FORM_Y+12},
	{FORM_TEXT, "Minimum row precharge time: --- ns", FORM_X+2,FORM_Y+13},
	{FORM_TEXT, "Minimum row active to active delay: --- ns", FORM_X+2,FORM_Y+14},
	{FORM_TEXT, "Minimum RAS to CAS delay: --- ns", FORM_X+2,FORM_Y+15},
	{FORM_TEXT, "Module bank density: --- MB", FORM_X+2,FORM_Y+16},
	{FORM_TEXT, "Module manufacturer ID: ----------------", FORM_X+2,FORM_Y+17},
	{FORM_TEXT, "Module manufacturing date: --/----", FORM_X+2,FORM_Y+18},
	{FORM_TEXT, "Module attributes: ----", FORM_X+2,FORM_Y+19},
	{FORM_END, 0,0,0}
};

form_setting_t form_setting_sdram[]={
	{0, 0, NULL, SETTING_END}
};

/*--- Variables ---*/

static void initFormSdram(void);

const form_menu_t form_menu_sdram={
	displayFormSdram,
	NULL,
	initFormSdram,
	NULL
};

static unsigned long cookie_ct60;
static char has_ct60;

/*--- Functions prototypes ---*/

void initFormSdram(void)
{
	unsigned char buffer[128];
	void *old_stack;
	int err, i, j, found, week, year;

	has_ct60 = getCookie(C_CT60, &cookie_ct60);

	if (!has_ct60) {
		return;
	}

	old_stack = (void *) Super(0);
	err = ct60_read_info_sdram(buffer);
	Super(old_stack);

	if (err<0) {
		return;
	}

	if (buffer[SDRAM_TYPE] == 4) {
		strCopy(sdram_type, &form_sdram[FORM_MEMTYPE].text[FORM_MEMTYPE_POS]);
	}
	format_number(&form_sdram[FORM_ROWS].text[FORM_ROWS_POS], buffer[SDRAM_ROWS], 3, ' ');
	format_number(&form_sdram[FORM_COLUMNS].text[FORM_COLUMNS_POS], buffer[SDRAM_COLUMNS], 3, ' ');
	format_number(&form_sdram[FORM_BANKS].text[FORM_BANKS_POS], buffer[SDRAM_DIMMS], 3, ' ');
	format_number(&form_sdram[FORM_WIDTH].text[FORM_WIDTH_POS], (buffer[SDRAM_WIDTH+1]<<8)|buffer[SDRAM_WIDTH], 5, ' ');
	format_number(&form_sdram[FORM_VOLT].text[FORM_VOLT_POS], buffer[SDRAM_VOLTAGE], 3, ' ');
	format_number(&form_sdram[FORM_CYCLE].text[FORM_CYCLE_POS_INT], buffer[SDRAM_CYCLE]>>4, 2, ' ');
	format_number(&form_sdram[FORM_CYCLE].text[FORM_CYCLE_POS_FRAC], buffer[SDRAM_CYCLE] & 15, 2, '0');
	format_number(&form_sdram[FORM_ACCESS].text[FORM_ACCESS_POS_INT], buffer[SDRAM_ACCESS]>>4, 2, ' ');
	format_number(&form_sdram[FORM_ACCESS].text[FORM_ACCESS_POS_FRAC], buffer[SDRAM_ACCESS] & 15, 2, '0');
	if (buffer[SDRAM_CONFIG]<3) {
		strCopy(sdram_config[buffer[SDRAM_CONFIG]], &form_sdram[FORM_CONFIG].text[FORM_CONFIG_POS]);
	}
	if (buffer[SDRAM_REFRESH]<6) {
		strCopy(sdram_refresh[buffer[SDRAM_REFRESH]], &form_sdram[FORM_REFRESH].text[FORM_REFRESH_POS]);
	}
	format_number(&form_sdram[FORM_NUMBANKS].text[FORM_NUMBANKS_POS], buffer[SDRAM_BANKS], 3, ' ');
	format_number(&form_sdram[FORM_PRECHARGE].text[FORM_PRECHARGE_POS], buffer[SDRAM_PRECHARGE], 3, ' ');
	format_number(&form_sdram[FORM_ACTIVE].text[FORM_ACTIVE_POS], buffer[SDRAM_ACTIVE], 3, ' ');
	format_number(&form_sdram[FORM_RASCAS].text[FORM_RASCAS_POS], buffer[SDRAM_RASCAS], 3, ' ');
	format_number(&form_sdram[FORM_DENSITY].text[FORM_DENSITY_POS], buffer[SDRAM_DENSITY]<<2, 3, ' ');
	format_number_hex(&form_sdram[FORM_ATTR].text[FORM_ATTR_POS], buffer[SDRAM_ATTRIBS], 2, 1);

	found = 0;
	for (i=0; i<13; i++) {
		if (buffer[SDRAM_MAN_ID] == sdram_manufacturers[i][0]) {
			for (j=0; j<16; j++) {
				form_sdram[FORM_MANID].text[FORM_MANID_POS+j]=' ';
			}
			strCopy(&sdram_manufacturers[i][1], &form_sdram[FORM_MANID].text[FORM_MANID_POS]);
			found = 1;
			break;
		}
	}
	if (!found) {
		for (i=0; i<8; i++) {
			format_number_hex(&form_sdram[FORM_MANID].text[FORM_MANID_POS+i*2], buffer[SDRAM_MAN_ID+i], 2, 0);
		}
	}

	week = buffer[SDRAM_MAN_DATE];
	year = buffer[SDRAM_MAN_DATE+1];
	if ((week & year) != 0xff) {
		if (year < 0x52) {
			week = buffer[SDRAM_MAN_DATE+1];
			year = buffer[SDRAM_MAN_DATE];
			year = (year<0x90 ? year+0x2000 : year+0x1900);
			format_number_hex(&form_sdram[FORM_MANDATE].text[FORM_MANDATE_POS], week, 2, 0);
			format_number_hex(&form_sdram[FORM_MANDATE].text[FORM_MANDATE_POS_YEAR], year, 4, 0);
		} else {
			format_number(&form_sdram[FORM_MANDATE].text[FORM_MANDATE_POS], week, 2, '0');
			format_number(&form_sdram[FORM_MANDATE].text[FORM_MANDATE_POS_YEAR], year+1900, 4, '0');
		}
	}
}

void displayFormSdram(void)
{
	vt_displayForm(form_sdram);
}
