/*
	CT60 Setup
	CT60 infos

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
#include "form_ct60.h"
#include "misc.h"
#include "ct60.h"
#include "hw_regs.h"

/*--- Defines ---*/

#define FORM_ABE 1
#define FORM_ABE_POS 5
#define FORM_SDR (FORM_ABE+1)
#define FORM_SDR_POS 5
#define FORM_ETHERNAT (FORM_SDR+1)
#define FORM_ETHERNAT_POS 13
#define FORM_SUPERVIDEL (FORM_ETHERNAT+1)
#define FORM_SUPERVIDEL_POS 13
#define FORM_CTPCI (FORM_SUPERVIDEL+1)
#define FORM_CTPCI_POS 13

/*--- Const ---*/

static form_t form_ct60[]={
	{FORM_TITLE, "CT60", FORM_X+((FORM_W-4)>>1), FORM_Y},
	{FORM_TEXT, "ABE: --", FORM_X+2,FORM_Y+2},
	{FORM_TEXT, "SDR: --", FORM_X+2,FORM_Y+3},
	{FORM_TEXT, "ETHERNAT:   [-]", FORM_X+2,FORM_Y+5},
	{FORM_TEXT, "SUPERVIDEL: [-]", FORM_X+2,FORM_Y+6},
	{FORM_TEXT, "CTPCI:      [-]", FORM_X+2,FORM_Y+7},
	{FORM_END, 0,0,0}
};

/*--- Variables ---*/

static void initFormCt60(void);

const form_menu_t form_menu_ct60={
	displayFormCt60,
	NULL,
	initFormCt60,
	NULL
};

/*--- Functions prototypes ---*/

/*--- Functions ---*/

static void initFormCt60(void)
{
	unsigned long cookie_cpu, chip_code, cookie_ct60;
	void *oldpile;
	char has_ct60;

	has_ct60 = getCookie(C_CT60, &cookie_ct60);

	if (!has_ct60) {
		return;
	}

	/* Read ABE,SDR versions */
	chip_code = ct60_rw_parameter(CT60_MODE_READ, CT60_ABE_CODE, NULL);
	form_ct60[FORM_ABE].text[FORM_ABE_POS] = (chip_code>>8) & 0xff;
	form_ct60[FORM_ABE].text[FORM_ABE_POS+1] = chip_code & 0xff;

	chip_code = ct60_rw_parameter(CT60_MODE_READ, CT60_SDR_CODE, NULL);
	form_ct60[FORM_SDR].text[FORM_SDR_POS] = (chip_code>>8) & 0xff;
	form_ct60[FORM_SDR].text[FORM_SDR_POS+1] = chip_code & 0xff;

	/* Detect CT60 devices */

	/* CPU */
	if (!getCookie(C__CPU, &cookie_cpu)) {
		cookie_cpu = 0;
	}

	oldpile=(void *)Super(NULL);

	form_ct60[FORM_ETHERNAT].text[FORM_ETHERNAT_POS] =
		(HW_RegDetect(cookie_cpu, 0x80000000)
		? 'X' : ' ');

	form_ct60[FORM_SUPERVIDEL].text[FORM_SUPERVIDEL_POS] =
		(HW_RegDetect(cookie_cpu, 0x30000000)
		? 'X' : ' ');

	form_ct60[FORM_CTPCI].text[FORM_CTPCI_POS] =
		(HW_RegDetect(cookie_cpu, 0xe8000000)
		? 'X' : ' ');

	Super(oldpile);
}

void displayFormCt60(void)
{
	vt_displayForm(form_ct60);
}
