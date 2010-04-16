/*
	CT60 Setup
	CPU settings

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

#include "config.h"
#include "form_vt.h"
#include "form_cpu.h"
#include "misc.h"
#include "ct60.h"
#include "ct60_ctcm.h"

/*--- Defines ---*/

#define FORM_CPU 1
#define FORM_CPU_POS 5
#define FORM_FPU (FORM_CPU+1)
#define FORM_FPU_POS 5
#define FORM_CHIP (FORM_FPU+1)
#define FORM_CHIP_POS 6
#define FORM_REVISION (FORM_CHIP+1)
#define FORM_REVISION_POS 10
#define FORM_MASK (FORM_REVISION+1)
#define FORM_MASK_POS 6
#define FORM_FREQ (FORM_MASK+1)
#define FORM_FREQ_INT 13
#define FORM_FREQ_FRAC 17
#define FORM_TEMP (FORM_FREQ+1)
#define FORM_TEMP_INT 13
#define FORM_RELOAD (FORM_TEMP+1)
#define FORM_SAVE (FORM_RELOAD+1)

#define FORM_SETTING_FREQ 0
#define FORM_SETTING_RELOAD 1
#define FORM_SETTING_SAVE 2

#define CHAR_DEG	"\xf8"

/*--- Const ---*/

static void reloadFormCpu(void);
static void saveFormCpu(void);
static void updownFreq(int direction);

static const char *softFpu="Soft ";
static const char *hardFpu="6888X";

static const char *chip_type[2]={
	"68060     ",
	"68LC/EC060"
};

static const char *chip_mask[4]={
	"D00W/D11W",
	"F43G/G65V",
	"F84W     ",
	"E41J     "
};

static form_t form_cpu[]={
	{FORM_TITLE, "CPU", FORM_X+((FORM_W-3)>>1), FORM_Y},
	{FORM_TEXT, "CPU: -----", FORM_X+2,FORM_Y+2},
	{FORM_TEXT, "FPU: -----", FORM_X+2,FORM_Y+3},
	{FORM_TEXT, "Chip: ----------", FORM_X+2,FORM_Y+5},
	{FORM_TEXT, "Revision: ---", FORM_X+2,FORM_Y+6},
	{FORM_TEXT, "Mask: --------------", FORM_X+2,FORM_Y+7},
	{FORM_TEXT, "Frequency  : ---.--- MHz", FORM_X+2,FORM_Y+9},
	{FORM_TEXT, "Temperature: --- " CHAR_DEG "C", FORM_X+2,FORM_Y+10},
	{FORM_TEXT, "Reload settings", FORM_X+2,FORM_Y+12},
	{FORM_TEXT, "Save settings", FORM_X+2,FORM_Y+13},
#ifndef SETUP_STANDALONE
	{FORM_TEXT, "IMPORTANT NOTE: changing CPU frequency requires a reset,", FORM_X+2,FORM_Y+FORM_H-4},
	{FORM_TEXT, "and will be forced when you exit this program.", FORM_X+2,FORM_Y+FORM_H-3},
#endif
	{FORM_END, 0,0,0}
};

form_setting_t form_setting_cpu[]={
	{FORM_X+2+13,FORM_Y+9, NULL, SETTING_UPDOWN, 7, updownFreq},	/* Freq */
	{FORM_X+2,FORM_Y+12, NULL, SETTING_FUNC, 0, reloadFormCpu},	/* Reload settings */
	{FORM_X+2,FORM_Y+13, NULL, SETTING_FUNC, 0, saveFormCpu},	/* Save settings */
	{0, 0, NULL, SETTING_END}
};

/*--- Global variables ---*/

char cpufreq_changed;

/*--- Variables ---*/

static void initFormCpu(void);
static void confirmFormCpu(int num_setting, conf_setting_u confSetting);

const form_menu_t form_menu_cpu={
	displayFormCpu,
	updateFormCpu,
	initFormCpu,
	confirmFormCpu
};

static unsigned long start_tick, cur_tick;
static unsigned long frequency = 0, min_freq = 0, max_freq = 0;
static unsigned long cookie_ct60;
static char has_ct60;

/*--- Functions ---*/

static void readCT60Freq(void);
static void readCT60Temp(void);

/*--- Functions prototypes ---*/

void initFormCpu(void)
{
	unsigned long cookie_cpu, cookie_fpu;

	start_tick = getTicks();

	form_setting_cpu[FORM_SETTING_FREQ].text = &form_cpu[FORM_FREQ].text[FORM_FREQ_INT];
	form_setting_cpu[FORM_SETTING_RELOAD].text = &form_cpu[FORM_RELOAD].text[0];
	form_setting_cpu[FORM_SETTING_SAVE].text = &form_cpu[FORM_SAVE].text[0];

	/* CPU */
	if (!getCookie(C__CPU, &cookie_cpu)) {
		cookie_cpu = 0;
	}
	format_number(&form_cpu[FORM_CPU].text[FORM_CPU_POS], 68000+cookie_cpu, 5, ' ');

	if (cookie_cpu==60) {
		void *old_stack;
		unsigned long pcr;
		int rev, num_rev;

		old_stack = (void *) Super(0);
		pcr = ct60_cpu_read_pcr();
		Super(old_stack);

		strCopy(chip_type[(pcr>>16) & 1], &form_cpu[FORM_CHIP].text[FORM_CHIP_POS]);

		rev = (pcr>>8) & 0xff;
		format_number(&form_cpu[FORM_REVISION].text[FORM_REVISION_POS], rev, 3, ' ');
		if (((pcr>>16) & 1)==0) {
			num_rev = 0;
			max_freq = MAX_FREQ_REV1;
			min_freq = MIN_FREQ_REV1;
			if ((rev==1) || (rev==5)) {
				num_rev=1;
			} else if (rev==2) {
				num_rev=2;
			} else if (rev>=6) {
				max_freq = MAX_FREQ_REV6;
				min_freq = MIN_FREQ_REV6;
				num_rev=3;
			}
			strCopy(chip_mask[num_rev], &form_cpu[FORM_MASK].text[FORM_MASK_POS]);
		}
	}

	/* FPU */
	if (!getCookie(C__FPU, &cookie_fpu)) {
		cookie_fpu = 0;
	}

	if (cookie_fpu & 0xffff) {
		strCopy(softFpu, &form_cpu[FORM_FPU].text[FORM_FPU_POS]);
	} else {
		switch((cookie_fpu>>16) & 0xfffe) {
			case 2:
			case 4:
			case 6:
				strCopy(hardFpu, &form_cpu[FORM_FPU].text[FORM_FPU_POS]);
				break;
			case 8:
				format_number(&form_cpu[FORM_FPU].text[FORM_FPU_POS], 68040, 5, ' ');
				break;
			case 16:
				format_number(&form_cpu[FORM_FPU].text[FORM_FPU_POS], 68060, 5, ' ');
				break;
		}
	}

	has_ct60 = getCookie(C_CT60, &cookie_ct60);

	if (has_ct60) {
		/* CT60 frequency */
		if (frequency==0) {
			readCT60Freq();
		}

		/* CT60 temperature */
		readCT60Temp();
	}
}

void displayFormCpu(void)
{
	vt_displayForm(form_cpu);
}

void updateFormCpu(void)
{
	/* Update temperature after 5 seconds */

	cur_tick = getTicks();
	if (cur_tick-start_tick<5*200) {
		return;
	}

	start_tick = cur_tick;

	/* CT60 temperature */
	if (has_ct60) {
		readCT60Temp();

		vt_displayForm_idx(form_cpu, FORM_TEMP, 1);
	}
}

static void reloadFormCpu(void)
{
	if (has_ct60) {
		conf_setting_u confSetting;

		readCT60Freq();

		confirmFormCpu(FORM_SETTING_FREQ, confSetting);
	}
}

static void saveFormCpu(void)
{
	if (has_ct60) {
		if (ct60_write_clock(frequency, CT60_CLOCK_WRITE_EEPROM)<0) {
			/* Error */
		} else {
			ct60_rw_parameter(CT60_MODE_WRITE,CT60_CLOCK,(long)frequency);
			cpufreq_changed = 1;
		}
	}
}

static void confirmFormCpu(int num_setting, conf_setting_u confSetting)
{
	switch(num_setting) {
		case FORM_SETTING_FREQ:
			format_number(&form_cpu[FORM_FREQ].text[FORM_FREQ_INT], frequency/1000, 3, ' ');
			format_number(&form_cpu[FORM_FREQ].text[FORM_FREQ_FRAC], frequency%1000, 3, '0');
			break;
	}

	vt_displayForm_idx(form_cpu, FORM_FREQ, 1);
}

static void updownFreq(int direction)
{
	switch(direction) {
		case SETTING_DIR_UP:
			frequency -= ct60_freq_step;
			if (frequency < min_freq) {
				frequency = min_freq;
			}
			break;
		case SETTING_DIR_DOWN:
			frequency += ct60_freq_step;
			if (frequency>max_freq) {
				frequency=max_freq;
			}
			break;
		case SETTING_DIR_PRINT:
			{
				char newfreq[8]={0};

				format_number(&newfreq[0], frequency/1000, 3, ' ');
				newfreq[3]='.';
				format_number(&newfreq[4], frequency%1000, 3, '0');

				Cconws(newfreq);
			}
			break;
	}
}

static void readCT60Freq()
{
	frequency = ct60_read_clock();

	if (frequency>0) {
		format_number(&form_cpu[FORM_FREQ].text[FORM_FREQ_INT], frequency/1000, 3, ' ');
		format_number(&form_cpu[FORM_FREQ].text[FORM_FREQ_FRAC], frequency%1000, 3, '0');
	}
}

static void readCT60Temp()
{
	int temp;

	temp = ct60_read_core_temperature(CT60_CELCIUS);
	if (temp<=0) {
		return;
	}

	format_number(&form_cpu[FORM_TEMP].text[FORM_TEMP_INT], temp, 3, ' ');
}
